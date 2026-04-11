#pragma once

#include <string>
#include <vector>

#include "spatial_preview/MathTypes.hpp"

namespace spatial_preview {

struct TrackKey {
  double t = 0.0;
  Vec3 position;
  Vec3 rotation_euler_deg;
  std::string ease_in = "auto";
  std::string ease_out = "auto";
};

struct TrajectoryTrack {
  std::string space = "world";
  std::string interpolation = "linear";
  std::vector<TrackKey> keys;
};

struct Listener {
  std::string id;
  TrajectoryTrack track;
};

struct Source {
  std::string id;
  std::string audio_asset;
  double gain_db = 0.0;
  TrajectoryTrack track;
};

struct ProjectMetadata {
  std::string title;
  int sample_rate = 48000;
  double duration_sec = 0.0;
  double tempo_bpm = 120.0;
};

struct Project {
  int format_version = 1;
  ProjectMetadata metadata;
  Listener listener;
  std::vector<Source> sources;
  std::size_t groups_count = 0;
};

}  // namespace spatial_preview
