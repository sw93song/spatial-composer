#pragma once

#include "spatial_preview/ProjectTypes.hpp"

namespace spatial_preview {

class TrajectoryEvaluator {
 public:
  Transform evaluate(const TrajectoryTrack& track, double time_sec) const;
};

}  // namespace spatial_preview
