#pragma once

#include <cstddef>
#include <string>
#include <unordered_map>
#include <vector>

namespace spatial_preview {

struct AudioBuffer {
  int sample_rate = 48000;
  int channels = 1;
  std::vector<float> samples;

  std::size_t frame_count() const;
};

class AudioAssetRegistry {
 public:
  const AudioBuffer& load_or_generate(const std::string& asset_path,
                                      const std::string& source_id,
                                      int project_sample_rate);

 private:
  std::unordered_map<std::string, AudioBuffer> cache_;
};

}  // namespace spatial_preview
