#pragma once

#include <string>

#include "spatial_preview/AudioAssetRegistry.hpp"

namespace spatial_preview {

AudioBuffer load_audio_file_with_miniaudio(const std::string& asset_path);
void write_audio_file_with_miniaudio(const std::string& output_path, const AudioBuffer& buffer);

}  // namespace spatial_preview
