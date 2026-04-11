#include "spatial_preview/ProjectLoader.hpp"

#include <algorithm>
#include <sstream>
#include <stdexcept>

#include "spatial_preview/Json.hpp"

namespace spatial_preview {

namespace {

[[noreturn]] void fail(const std::string& message) {
  throw std::runtime_error("project validation failed: " + message);
}

std::string require_string(const JsonValue& value, const std::string& path) {
  if (!value.is_string()) {
    fail(path + " must be a string");
  }
  return value.as_string();
}

double require_number(const JsonValue& value, const std::string& path) {
  if (!value.is_number()) {
    fail(path + " must be a number");
  }
  return value.as_number();
}

int require_int(const JsonValue& value, const std::string& path) {
  const double raw = require_number(value, path);
  const int as_int = static_cast<int>(raw);
  if (static_cast<double>(as_int) != raw) {
    fail(path + " must be an integer");
  }
  return as_int;
}

JsonValue::Array require_array(const JsonValue& value, const std::string& path) {
  if (!value.is_array()) {
    fail(path + " must be an array");
  }
  return value.as_array();
}

void require_object(const JsonValue& value, const std::string& path) {
  if (!value.is_object()) {
    fail(path + " must be an object");
  }
}

Vec3 parse_vec3(const JsonValue& value, const std::string& path) {
  const auto& array = require_array(value, path);
  if (array.size() != 3) {
    fail(path + " must contain exactly 3 numbers");
  }

  return {
      require_number(array[0], path + "[0]"),
      require_number(array[1], path + "[1]"),
      require_number(array[2], path + "[2]"),
  };
}

TrackKey parse_track_key(const JsonValue& value, const std::string& path) {
  require_object(value, path);

  TrackKey key;
  key.t = require_number(value.at("t"), path + ".t");
  key.position = parse_vec3(value.at("position"), path + ".position");
  key.rotation_euler_deg = parse_vec3(value.at("rotation_euler_deg"), path + ".rotation_euler_deg");
  key.ease_in = require_string(value.at("ease_in"), path + ".ease_in");
  key.ease_out = require_string(value.at("ease_out"), path + ".ease_out");
  return key;
}

TrajectoryTrack parse_track(const JsonValue& value, const std::string& path) {
  require_object(value, path);

  TrajectoryTrack track;
  track.space = require_string(value.at("space"), path + ".space");
  track.interpolation = require_string(value.at("interpolation"), path + ".interpolation");

  if (track.space != "world" && track.space != "listener" && track.space != "group") {
    fail(path + ".space must be world, listener, or group");
  }

  if (track.interpolation != "linear" && track.interpolation != "bezier" &&
      track.interpolation != "catmull_rom") {
    fail(path + ".interpolation must be linear, bezier, or catmull_rom");
  }

  const JsonValue& keys_json = value.at("keys");
  const auto& keys_value = require_array(keys_json, path + ".keys");
  if (keys_value.empty()) {
    fail(path + ".keys must not be empty");
  }

  track.keys.reserve(keys_value.size());
  for (std::size_t i = 0; i < keys_value.size(); ++i) {
    track.keys.push_back(parse_track_key(keys_value[i], path + ".keys[" + std::to_string(i) + "]"));
  }

  for (std::size_t i = 1; i < track.keys.size(); ++i) {
    if (track.keys[i].t < track.keys[i - 1].t) {
      fail(path + ".keys must be sorted by ascending time");
    }
  }

  return track;
}

Listener parse_listener(const JsonValue& value, const std::string& path) {
  require_object(value, path);

  Listener listener;
  listener.id = require_string(value.at("id"), path + ".id");
  listener.track = parse_track(value.at("track"), path + ".track");
  return listener;
}

Source parse_source(const JsonValue& value, const std::string& path) {
  require_object(value, path);

  Source source;
  source.id = require_string(value.at("id"), path + ".id");
  source.audio_asset = require_string(value.at("audio_asset"), path + ".audio_asset");
  source.gain_db = require_number(value.at("gain_db"), path + ".gain_db");
  source.track = parse_track(value.at("track"), path + ".track");
  return source;
}

}  // namespace

Project ProjectLoader::load(const std::string& path) const {
  const JsonValue root = parse_json_file(path);
  require_object(root, "root");

  Project project;
  project.format_version = require_int(root.at("format_version"), "format_version");
  if (project.format_version != 1) {
    fail("format_version must be 1");
  }

  const JsonValue& project_value = root.at("project");
  require_object(project_value, "project");
  project.metadata.title = require_string(project_value.at("title"), "project.title");
  project.metadata.sample_rate = require_int(project_value.at("sample_rate"), "project.sample_rate");
  project.metadata.duration_sec =
      require_number(project_value.at("duration_sec"), "project.duration_sec");
  project.metadata.tempo_bpm = require_number(project_value.at("tempo_bpm"), "project.tempo_bpm");

  project.listener = parse_listener(root.at("listener"), "listener");

  const JsonValue& sources_json = root.at("sources");
  const auto& sources_value = require_array(sources_json, "sources");
  project.sources.reserve(sources_value.size());
  for (std::size_t i = 0; i < sources_value.size(); ++i) {
    project.sources.push_back(parse_source(sources_value[i], "sources[" + std::to_string(i) + "]"));
  }

  project.groups_count = require_array(root.at("groups"), "groups").size();
  return project;
}

Project ProjectLoader::load_from_json_text(const std::string& json_text) const {
  const JsonValue root = parse_json(json_text);
  require_object(root, "root");

  Project project;
  project.format_version = require_int(root.at("format_version"), "format_version");
  if (project.format_version != 1) {
    fail("format_version must be 1");
  }

  const JsonValue& project_value = root.at("project");
  require_object(project_value, "project");
  project.metadata.title = require_string(project_value.at("title"), "project.title");
  project.metadata.sample_rate = require_int(project_value.at("sample_rate"), "project.sample_rate");
  project.metadata.duration_sec =
      require_number(project_value.at("duration_sec"), "project.duration_sec");
  project.metadata.tempo_bpm = require_number(project_value.at("tempo_bpm"), "project.tempo_bpm");

  project.listener = parse_listener(root.at("listener"), "listener");

  const JsonValue& sources_json = root.at("sources");
  const auto& sources_value = require_array(sources_json, "sources");
  project.sources.reserve(sources_value.size());
  for (std::size_t i = 0; i < sources_value.size(); ++i) {
    project.sources.push_back(parse_source(sources_value[i], "sources[" + std::to_string(i) + "]"));
  }

  project.groups_count = require_array(root.at("groups"), "groups").size();
  return project;
}

}  // namespace spatial_preview
