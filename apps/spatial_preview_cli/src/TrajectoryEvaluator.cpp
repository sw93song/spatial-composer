#include "spatial_preview/TrajectoryEvaluator.hpp"

#include <algorithm>

#include "spatial_preview/MathTypes.hpp"

namespace spatial_preview {

Transform TrajectoryEvaluator::evaluate(const TrajectoryTrack& track, const double time_sec) const {
  if (track.keys.empty()) {
    return {};
  }

  if (time_sec <= track.keys.front().t) {
    return {track.keys.front().position, track.keys.front().rotation_euler_deg};
  }

  if (time_sec >= track.keys.back().t) {
    return {track.keys.back().position, track.keys.back().rotation_euler_deg};
  }

  const auto upper = std::lower_bound(
      track.keys.begin(), track.keys.end(), time_sec, [](const TrackKey& key, const double value) {
        return key.t < value;
      });

  if (upper == track.keys.begin()) {
    return {upper->position, upper->rotation_euler_deg};
  }

  const TrackKey& b = *upper;
  const TrackKey& a = *(upper - 1);
  const double span = b.t - a.t;
  const double alpha = span > 0.0 ? (time_sec - a.t) / span : 0.0;

  // v1 treats all interpolation modes as editable piecewise linear segments.
  return {
      lerp(a.position, b.position, alpha),
      lerp(a.rotation_euler_deg, b.rotation_euler_deg, alpha),
  };
}

}  // namespace spatial_preview
