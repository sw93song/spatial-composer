#pragma once

#include <string>

#include "spatial_preview/ProjectTypes.hpp"

namespace spatial_preview {

class ProjectLoader {
 public:
  Project load(const std::string& path) const;
  Project load_from_json_text(const std::string& json_text) const;
};

}  // namespace spatial_preview
