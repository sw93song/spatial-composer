#include "spatial_preview/OfflineRenderCommand.hpp"

#include <chrono>
#include <filesystem>
#include <iostream>
#include <stdexcept>
#include <thread>

#include "spatial_preview/AudioAssetRegistry.hpp"
#include "spatial_preview/MiniaudioIO.hpp"
#include "spatial_preview/ProjectLoader.hpp"
#include "spatial_preview/SpatialPreviewRenderer.hpp"

namespace spatial_preview {

namespace {

void render_once(const std::string& project_path, const std::string& output_path) {
  const ProjectLoader loader;
  AudioAssetRegistry assets;
  const SpatialPreviewRenderer renderer;
  const Project project = loader.load(project_path);
  const AudioBuffer output = renderer.render_stereo_preview(project, assets);

  const std::filesystem::path parent_path = std::filesystem::path(output_path).parent_path();
  if (!parent_path.empty()) {
    std::filesystem::create_directories(parent_path);
  }
  write_audio_file_with_miniaudio(output_path, output);

  std::cout << "rendered " << output_path << " (" << output.frame_count() << " frames at "
            << output.sample_rate << " Hz)\n";
}

}  // namespace

void OfflineRenderCommand::render_project_to_wav(const std::string& project_path,
                                                 const std::string& output_path) const {
  render_once(project_path, output_path);
}

void OfflineRenderCommand::watch_and_render(const std::string& project_path,
                                            const std::string& output_path) const {
  namespace fs = std::filesystem;

  fs::file_time_type last_write_time = fs::last_write_time(project_path);
  render_once(project_path, output_path);
  std::cout << "watching " << project_path << " for changes\n";

  for (;;) {
    std::this_thread::sleep_for(std::chrono::milliseconds(1000));
    const fs::file_time_type current_write_time = fs::last_write_time(project_path);
    if (current_write_time != last_write_time) {
      last_write_time = current_write_time;
      try {
        render_once(project_path, output_path);
      } catch (const std::exception& error) {
        std::cerr << "render failed after file change: " << error.what() << '\n';
      }
    }
  }
}

}  // namespace spatial_preview
