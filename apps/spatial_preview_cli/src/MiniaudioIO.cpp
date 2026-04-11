#include "spatial_preview/MiniaudioIO.hpp"

#include <cmath>
#include <stdexcept>
#include <vector>

#define MA_NO_ENGINE
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

namespace spatial_preview {

AudioBuffer load_audio_file_with_miniaudio(const std::string& asset_path) {
  ma_decoder decoder{};
  if (ma_decoder_init_file(asset_path.c_str(), nullptr, &decoder) != MA_SUCCESS) {
    throw std::runtime_error("miniaudio failed to open asset: " + asset_path);
  }

  AudioBuffer buffer;
  buffer.sample_rate = static_cast<int>(decoder.outputSampleRate);
  buffer.channels = static_cast<int>(decoder.outputChannels);

  ma_uint64 frame_count = 0;
  if (ma_decoder_get_length_in_pcm_frames(&decoder, &frame_count) != MA_SUCCESS) {
    ma_decoder_uninit(&decoder);
    throw std::runtime_error("miniaudio failed to get frame count: " + asset_path);
  }

  buffer.samples.resize(static_cast<std::size_t>(frame_count) * buffer.channels);
  ma_uint64 frames_read = 0;
  if (ma_decoder_read_pcm_frames(&decoder, buffer.samples.data(), frame_count, &frames_read) !=
      MA_SUCCESS) {
    ma_decoder_uninit(&decoder);
    throw std::runtime_error("miniaudio failed to read frames: " + asset_path);
  }
  buffer.samples.resize(static_cast<std::size_t>(frames_read) * buffer.channels);

  if (buffer.sample_rate <= 0) {
    buffer.sample_rate = 48000;
  }
  if (buffer.channels <= 0) {
    buffer.channels = 1;
  }
  for (float& sample : buffer.samples) {
    if (!std::isfinite(sample)) {
      sample = 0.0f;
    }
  }

  ma_decoder_uninit(&decoder);
  return buffer;
}

void write_audio_file_with_miniaudio(const std::string& output_path, const AudioBuffer& buffer) {
  ma_encoder_config config =
      ma_encoder_config_init(ma_encoding_format_wav, ma_format_f32, buffer.channels,
                             static_cast<ma_uint32>(buffer.sample_rate));
  ma_encoder encoder{};
  if (ma_encoder_init_file(output_path.c_str(), &config, &encoder) != MA_SUCCESS) {
    throw std::runtime_error("miniaudio failed to open output file: " + output_path);
  }

  const ma_uint64 frame_count = static_cast<ma_uint64>(buffer.frame_count());
  if (ma_encoder_write_pcm_frames(&encoder, buffer.samples.data(), frame_count, nullptr) !=
      MA_SUCCESS) {
    ma_encoder_uninit(&encoder);
    throw std::runtime_error("miniaudio failed to write output file: " + output_path);
  }

  ma_encoder_uninit(&encoder);
}

}  // namespace spatial_preview
