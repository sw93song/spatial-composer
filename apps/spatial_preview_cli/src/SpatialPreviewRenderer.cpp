#include "spatial_preview/SpatialPreviewRenderer.hpp"

#include <algorithm>
#include <cmath>
#include <numbers>
#include <vector>

#if defined(WOULDYOU_HAS_STEAM_AUDIO)
#include "phonon.h"
#endif

#include "spatial_preview/MathTypes.hpp"
#include "spatial_preview/TrajectoryEvaluator.hpp"

namespace spatial_preview {

namespace {

double db_to_linear(const double value_db) {
  return std::pow(10.0, value_db / 20.0);
}

bool is_finite(const double value) {
  return std::isfinite(value);
}

bool is_finite_vec3(const Vec3& value) {
  return is_finite(value.x) && is_finite(value.y) && is_finite(value.z);
}

double length_squared(const Vec3& value) {
  return value.x * value.x + value.y * value.y + value.z * value.z;
}

Vec3 sanitize_vec3(const Vec3& value, const Vec3& fallback) {
  if (!is_finite_vec3(value)) {
    return fallback;
  }
  return value;
}

Vec3 rotate_x(const Vec3& value, const double radians) {
  const double c = std::cos(radians);
  const double s = std::sin(radians);
  return {value.x, value.y * c - value.z * s, value.y * s + value.z * c};
}

Vec3 rotate_y(const Vec3& value, const double radians) {
  const double c = std::cos(radians);
  const double s = std::sin(radians);
  return {value.x * c + value.z * s, value.y, -value.x * s + value.z * c};
}

Vec3 rotate_z(const Vec3& value, const double radians) {
  const double c = std::cos(radians);
  const double s = std::sin(radians);
  return {value.x * c - value.y * s, value.x * s + value.y * c, value.z};
}

#if !defined(WOULDYOU_HAS_STEAM_AUDIO)
Vec3 world_to_listener_space(const Vec3& relative, const Vec3& listener_rotation_deg) {
  Vec3 rotated = relative;
  rotated = rotate_z(rotated, -listener_rotation_deg.z * std::numbers::pi / 180.0);
  rotated = rotate_x(rotated, -listener_rotation_deg.x * std::numbers::pi / 180.0);
  rotated = rotate_y(rotated, -listener_rotation_deg.y * std::numbers::pi / 180.0);
  return rotated;
}
#endif

Vec3 rotate_local_to_world(const Vec3& value, const Vec3& rotation_deg) {
  Vec3 rotated = value;
  rotated = rotate_y(rotated, rotation_deg.y * std::numbers::pi / 180.0);
  rotated = rotate_x(rotated, rotation_deg.x * std::numbers::pi / 180.0);
  rotated = rotate_z(rotated, rotation_deg.z * std::numbers::pi / 180.0);
  return rotated;
}

float read_mono_sample(const AudioBuffer& buffer, double frame_position) {
  const std::size_t frame_count = buffer.frame_count();
  if (frame_count == 0 || buffer.channels <= 0 || !std::isfinite(frame_position)) {
    return 0.0f;
  }

  while (frame_position < 0.0) {
    frame_position += static_cast<double>(frame_count);
  }
  frame_position = std::fmod(frame_position, static_cast<double>(frame_count));

  const std::size_t frame_a = static_cast<std::size_t>(frame_position);
  const std::size_t frame_b = (frame_a + 1) % frame_count;
  const double alpha = frame_position - static_cast<double>(frame_a);

  auto mono_frame = [&](const std::size_t frame_index) -> float {
    float sum = 0.0f;
    for (int channel = 0; channel < buffer.channels; ++channel) {
      sum += buffer.samples[frame_index * static_cast<std::size_t>(buffer.channels) +
                            static_cast<std::size_t>(channel)];
    }
    return sum / static_cast<float>(buffer.channels);
  };

  const float a = mono_frame(frame_a);
  const float b = mono_frame(frame_b);
  const double blended = static_cast<double>(a) + static_cast<double>(b - a) * alpha;
  if (!std::isfinite(blended)) {
    return 0.0f;
  }
  return static_cast<float>(blended);
}

#if defined(WOULDYOU_HAS_STEAM_AUDIO)
IPLVector3 to_ipl(const Vec3& value) {
  return IPLVector3{
      static_cast<IPLfloat32>(value.x),
      static_cast<IPLfloat32>(value.y),
      static_cast<IPLfloat32>(value.z),
  };
}

AudioBuffer render_with_steam_audio(const Project& project, AudioAssetRegistry& assets) {
  constexpr int kFrameSize = 1024;

  IPLContextSettings context_settings{};
  context_settings.version = STEAMAUDIO_VERSION;
  context_settings.simdLevel = IPL_SIMDLEVEL_AVX2;
  // Keep runtime preview quiet and resilient. We sanitize buffers ourselves.
  context_settings.flags = static_cast<IPLContextFlags>(0);

  IPLContext context{};
  if (iplContextCreate(&context_settings, &context) != IPL_STATUS_SUCCESS) {
    throw std::runtime_error("Steam Audio context creation failed");
  }

  IPLAudioSettings audio_settings{};
  audio_settings.samplingRate = project.metadata.sample_rate;
  audio_settings.frameSize = kFrameSize;

  IPLHRTFSettings hrtf_settings{};
  hrtf_settings.type = IPL_HRTFTYPE_DEFAULT;
  hrtf_settings.volume = 1.0f;
  hrtf_settings.normType = IPL_HRTFNORMTYPE_RMS;

  IPLHRTF hrtf{};
  if (iplHRTFCreate(context, &audio_settings, &hrtf_settings, &hrtf) != IPL_STATUS_SUCCESS) {
    iplContextRelease(&context);
    throw std::runtime_error("Steam Audio HRTF creation failed");
  }

  IPLBinauralEffectSettings binaural_settings{};
  binaural_settings.hrtf = hrtf;

  std::vector<IPLBinauralEffect> effects(project.sources.size());
  for (std::size_t i = 0; i < project.sources.size(); ++i) {
    if (iplBinauralEffectCreate(context, &audio_settings, &binaural_settings, &effects[i]) !=
        IPL_STATUS_SUCCESS) {
      for (auto& effect : effects) {
        if (effect) {
          iplBinauralEffectRelease(&effect);
        }
      }
      iplHRTFRelease(&hrtf);
      iplContextRelease(&context);
      throw std::runtime_error("Steam Audio binaural effect creation failed");
    }
  }

  AudioBuffer output;
  output.sample_rate = project.metadata.sample_rate;
  output.channels = 2;
  const std::size_t total_frames = static_cast<std::size_t>(
      std::ceil(project.metadata.duration_sec * static_cast<double>(project.metadata.sample_rate)));
  output.samples.assign(total_frames * 2, 0.0f);

  std::vector<float> input_channel(static_cast<std::size_t>(kFrameSize), 0.0f);
  std::vector<float> left_channel(static_cast<std::size_t>(kFrameSize), 0.0f);
  std::vector<float> right_channel(static_cast<std::size_t>(kFrameSize), 0.0f);
  std::vector<IPLfloat32*> in_data = {input_channel.data()};
  std::vector<IPLfloat32*> out_data = {left_channel.data(), right_channel.data()};
  IPLAudioBuffer in_buffer{1, kFrameSize, in_data.data()};
  IPLAudioBuffer out_buffer{2, kFrameSize, out_data.data()};

  const TrajectoryEvaluator evaluator;
  for (std::size_t block_start = 0; block_start < total_frames; block_start += kFrameSize) {
    const int block_frames =
        static_cast<int>(std::min<std::size_t>(kFrameSize, total_frames - block_start));
    in_buffer.numSamples = block_frames;
    out_buffer.numSamples = block_frames;

    const double time_sec =
        static_cast<double>(block_start) / static_cast<double>(project.metadata.sample_rate);
    const Transform listener = evaluator.evaluate(project.listener.track, time_sec);
    const Vec3 listener_position = sanitize_vec3(listener.position, {0.0, 0.0, 0.0});
    const Vec3 listener_rotation =
        sanitize_vec3(listener.rotation_euler_deg, {0.0, 0.0, 0.0});
    const Vec3 listener_ahead =
        sanitize_vec3(rotate_local_to_world({0.0, 0.0, -1.0}, listener_rotation), {0.0, 0.0, -1.0});
    const Vec3 listener_up =
        sanitize_vec3(rotate_local_to_world({0.0, 1.0, 0.0}, listener_rotation), {0.0, 1.0, 0.0});

    for (std::size_t source_index = 0; source_index < project.sources.size(); ++source_index) {
      std::fill(input_channel.begin(), input_channel.end(), 0.0f);
      std::fill(left_channel.begin(), left_channel.end(), 0.0f);
      std::fill(right_channel.begin(), right_channel.end(), 0.0f);

      const auto& source = project.sources[source_index];
      const Transform source_transform = evaluator.evaluate(source.track, time_sec);
      const Vec3 source_position = sanitize_vec3(source_transform.position, listener_position);
      Vec3 relative_world = source_position - listener_position;
      if (!is_finite_vec3(relative_world) || length_squared(relative_world) < 1e-8) {
        relative_world = listener_ahead * 0.25;
      }
      const double distance = std::sqrt(relative_world.x * relative_world.x +
                                        relative_world.y * relative_world.y +
                                        relative_world.z * relative_world.z);
      const double attenuation = 1.0 / (1.0 + 0.35 * distance * distance);
      const double source_gain = db_to_linear(source.gain_db);

      const AudioBuffer& buffer =
          assets.load_or_generate(source.audio_asset, source.id, project.metadata.sample_rate);
      for (int frame = 0; frame < block_frames; ++frame) {
        const double source_frame = (time_sec + static_cast<double>(frame) /
                                                   static_cast<double>(project.metadata.sample_rate)) *
                                    static_cast<double>(std::max(buffer.sample_rate, 1));
        const double input_sample =
            static_cast<double>(read_mono_sample(buffer, source_frame)) * attenuation * source_gain;
        input_channel[static_cast<std::size_t>(frame)] =
            std::isfinite(input_sample) ? static_cast<float>(input_sample) : 0.0f;
      }

      IPLBinauralEffectParams params{};
      params.direction = iplCalculateRelativeDirection(
          context,
          to_ipl(source_position),
          to_ipl(listener_position),
          to_ipl(listener_ahead),
          to_ipl(listener_up));
      params.interpolation = IPL_HRTFINTERPOLATION_BILINEAR;
      params.spatialBlend = 1.0f;
      params.hrtf = hrtf;
      params.peakDelays = nullptr;

      iplBinauralEffectApply(effects[source_index], &params, &in_buffer, &out_buffer);

      for (int frame = 0; frame < block_frames; ++frame) {
        const std::size_t out_index = (block_start + static_cast<std::size_t>(frame)) * 2;
        const float left_sample = std::isfinite(left_channel[static_cast<std::size_t>(frame)])
                                      ? left_channel[static_cast<std::size_t>(frame)]
                                      : 0.0f;
        const float right_sample = std::isfinite(right_channel[static_cast<std::size_t>(frame)])
                                       ? right_channel[static_cast<std::size_t>(frame)]
                                       : 0.0f;
        output.samples[out_index] = std::clamp(
            output.samples[out_index] + left_sample, -1.0f, 1.0f);
        output.samples[out_index + 1] = std::clamp(
            output.samples[out_index + 1] + right_sample, -1.0f, 1.0f);
      }
    }
  }

  for (auto& effect : effects) {
    iplBinauralEffectRelease(&effect);
  }
  iplHRTFRelease(&hrtf);
  iplContextRelease(&context);
  return output;
}
#endif

}  // namespace

AudioBuffer SpatialPreviewRenderer::render_stereo_preview(const Project& project,
                                                          AudioAssetRegistry& assets) const {
#if defined(WOULDYOU_HAS_STEAM_AUDIO)
  return render_with_steam_audio(project, assets);
#else
  AudioBuffer output;
  output.sample_rate = project.metadata.sample_rate;
  output.channels = 2;

  const std::size_t total_frames = static_cast<std::size_t>(
      std::ceil(project.metadata.duration_sec * static_cast<double>(project.metadata.sample_rate)));
  output.samples.assign(total_frames * 2, 0.0f);

  const TrajectoryEvaluator evaluator;
  for (std::size_t frame = 0; frame < total_frames; ++frame) {
    const double time_sec =
        static_cast<double>(frame) / static_cast<double>(project.metadata.sample_rate);
    const Transform listener = evaluator.evaluate(project.listener.track, time_sec);

    double left = 0.0;
    double right = 0.0;

    for (const auto& source : project.sources) {
      const Transform source_transform = evaluator.evaluate(source.track, time_sec);
      const Vec3 relative_world = source_transform.position - listener.position;
      const Vec3 relative_local =
          world_to_listener_space(relative_world, listener.rotation_euler_deg);

      const double distance = std::sqrt(relative_local.x * relative_local.x +
                                        relative_local.y * relative_local.y +
                                        relative_local.z * relative_local.z);
      const double azimuth = std::atan2(relative_local.x, relative_local.z + 1e-6);
      const double pan = std::clamp(std::sin(azimuth), -1.0, 1.0);
      const double left_gain = std::sqrt(0.5 * (1.0 - pan));
      const double right_gain = std::sqrt(0.5 * (1.0 + pan));
      const double attenuation = 1.0 / (1.0 + 0.35 * distance * distance);
      const double source_gain = db_to_linear(source.gain_db);

      const AudioBuffer& buffer =
          assets.load_or_generate(source.audio_asset, source.id, project.metadata.sample_rate);
      const double source_frame =
          time_sec * static_cast<double>(buffer.sample_rate);
      const double sample = static_cast<double>(read_mono_sample(buffer, source_frame)) *
                            attenuation * source_gain;

      left += sample * left_gain;
      right += sample * right_gain;
    }

    output.samples[frame * 2] = static_cast<float>(std::clamp(left, -1.0, 1.0));
    output.samples[frame * 2 + 1] = static_cast<float>(std::clamp(right, -1.0, 1.0));
  }

  return output;
#endif
}

}  // namespace spatial_preview
