#pragma once

#include <string>

namespace spatial_preview {

class OfflineRenderCommand {
 public:
  void render_project_to_wav(const std::string& project_path, const std::string& output_path) const;
  void watch_and_render(const std::string& project_path, const std::string& output_path) const;
};

}  // namespace spatial_preview
