#pragma once

#include <string>

namespace spatial_preview {

class LiveSyncServer {
 public:
  void listen_and_render_tcp(int port, const std::string& output_path) const;
  bool receive_once_and_render_tcp(int port, const std::string& output_path, int timeout_ms) const;
};

}  // namespace spatial_preview
