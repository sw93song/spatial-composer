#pragma once

#include "spatial_preview/AudioAssetRegistry.hpp"
#include "spatial_preview/ProjectTypes.hpp"

namespace spatial_preview {

class SpatialPreviewRenderer {
 public:
  AudioBuffer render_stereo_preview(const Project& project, AudioAssetRegistry& assets) const;
};

}  // namespace spatial_preview
