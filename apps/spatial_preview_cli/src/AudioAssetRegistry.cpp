#include "spatial_preview/AudioAssetRegistry.hpp"

#include <cmath>
#include <filesystem>
#include <iostream>
#include <numbers>
#include <stdexcept>

#include "spatial_preview/MiniaudioIO.hpp"

namespace spatial_preview {

namespace {

AudioBuffer generate_fallback_tone(const std::string& source_id, int sample_rate) {
  constexpr double kDurationSec = 1.0;
  constexpr double kAmplitude = 0.18;

  AudioBuffer buffer;
  buffer.sample_rate = sample_rate;
  buffer.channels = 1;
  const std::size_t frames = static_cast<std::size_t>(kDurationSec * sample_rate);
  buffer.samples.resize(frames);

  const std::size_t hash = std::hash<std::string>{}(source_id);
  const double frequency = 180.0 + static_cast<double>(hash % 360);
  for (std::size_t frame = 0; frame < frames; ++frame) {
    const double t = static_cast<double>(frame) / static_cast<double>(sample_rate);
    const double envelope = 0.85 + 0.15 * std::sin(2.0 * std::numbers::pi * t);
    buffer.samples[frame] = static_cast<float>(
        std::sin(2.0 * std::numbers::pi * frequency * t) * kAmplitude * envelope);
  }

  return buffer;
}

}  // namespace

std::size_t AudioBuffer::frame_count() const {
  return channels > 0 ? samples.size() / static_cast<std::size_t>(channels) : 0;
}

const AudioBuffer& AudioAssetRegistry::load_or_generate(const std::string& asset_path,
                                                        const std::string& source_id,
                                                        const int project_sample_rate) {
  const std::string cache_key = asset_path.empty() ? "__generated__:" + source_id : asset_path;
  if (const auto iter = cache_.find(cache_key); iter != cache_.end()) {
    return iter->second;
  }

  AudioBuffer buffer;
  if (!asset_path.empty() && std::filesystem::exists(asset_path)) {
    buffer = load_audio_file_with_miniaudio(asset_path);
  } else {
    std::cerr << "warning: audio asset not found for source '" << source_id
              << "': " << (asset_path.empty() ? "<empty>" : asset_path)
              << " -- using generated fallback tone\n";
    buffer = generate_fallback_tone(source_id, project_sample_rate);
  }

  return cache_.emplace(cache_key, std::move(buffer)).first->second;
}

}  // namespace spatial_preview
