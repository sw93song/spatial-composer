#include "spatial_preview/LiveSyncServer.hpp"

#include <array>
#include <cstring>
#include <iostream>
#include <stdexcept>
#include <string>

#if defined(_WIN32)
#include <winsock2.h>
#include <ws2tcpip.h>
#pragma comment(lib, "ws2_32.lib")
using SocketHandle = SOCKET;
constexpr SocketHandle kInvalidSocket = INVALID_SOCKET;
#else
#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
using SocketHandle = int;
constexpr SocketHandle kInvalidSocket = -1;
#endif

#include "spatial_preview/AudioAssetRegistry.hpp"
#include "spatial_preview/MiniaudioIO.hpp"
#include "spatial_preview/ProjectLoader.hpp"
#include "spatial_preview/SpatialPreviewRenderer.hpp"

namespace spatial_preview {

namespace {

void close_socket(const SocketHandle socket_handle) {
#if defined(_WIN32)
  closesocket(socket_handle);
#else
  close(socket_handle);
#endif
}

struct SocketRuntime {
  SocketRuntime() {
#if defined(_WIN32)
    WSADATA wsa_data{};
    if (WSAStartup(MAKEWORD(2, 2), &wsa_data) != 0) {
      throw std::runtime_error("WSAStartup failed");
    }
#endif
  }

  ~SocketRuntime() {
#if defined(_WIN32)
    WSACleanup();
#endif
  }
};

void write_rendered_json_to_wav(const std::string& json_text, const std::string& output_path) {
  const ProjectLoader loader;
  const Project project = loader.load_from_json_text(json_text);
  AudioAssetRegistry assets;
  const SpatialPreviewRenderer renderer;
  const AudioBuffer output = renderer.render_stereo_preview(project, assets);
  write_audio_file_with_miniaudio(output_path, output);
  std::cout << "live-rendered " << output_path << " from TCP snapshot\n";
}

std::string read_line_from_socket(const SocketHandle socket_handle) {
  std::string line;
  char ch = '\0';
  for (;;) {
#if defined(_WIN32)
    const int received = recv(socket_handle, &ch, 1, 0);
#else
    const ssize_t received = recv(socket_handle, &ch, 1, 0);
#endif
    if (received <= 0) {
      return {};
    }
    if (ch == '\n') {
      return line;
    }
    line.push_back(ch);
  }
}

std::string read_exact_from_socket(const SocketHandle socket_handle, const std::size_t size) {
  std::string payload;
  payload.resize(size);
  std::size_t offset = 0;
  while (offset < size) {
#if defined(_WIN32)
    const int received =
        recv(socket_handle, payload.data() + offset, static_cast<int>(size - offset), 0);
#else
    const ssize_t received = recv(socket_handle, payload.data() + offset, size - offset, 0);
#endif
    if (received <= 0) {
      return {};
    }
    offset += static_cast<std::size_t>(received);
  }
  return payload;
}

bool send_all_to_socket(const SocketHandle socket_handle, const std::string& payload) {
  std::size_t offset = 0;
  while (offset < payload.size()) {
#if defined(_WIN32)
    const int sent = send(socket_handle, payload.data() + offset,
                          static_cast<int>(payload.size() - offset), 0);
#else
    const ssize_t sent = send(socket_handle, payload.data() + offset, payload.size() - offset, 0);
#endif
    if (sent <= 0) {
      return false;
    }
    offset += static_cast<std::size_t>(sent);
  }
  return true;
}

std::string read_snapshot_payload(const SocketHandle socket_handle) {
  const std::string header = read_line_from_socket(socket_handle);
  if (header.empty()) {
    return {};
  }
  const std::size_t size = static_cast<std::size_t>(std::stoull(header));
  return read_exact_from_socket(socket_handle, size);
}

void handle_snapshot_connection(const SocketHandle client_socket, const std::string& output_path) {
  try {
    const std::string payload = read_snapshot_payload(client_socket);
    if (payload.empty()) {
      send_all_to_socket(client_socket, "ERR empty-payload\n");
      return;
    }
    write_rendered_json_to_wav(payload, output_path);
    send_all_to_socket(client_socket, "OK rendered\n");
  } catch (const std::exception& error) {
    send_all_to_socket(client_socket, std::string("ERR ") + error.what() + "\n");
    throw;
  }
}

}  // namespace

void LiveSyncServer::listen_and_render_tcp(const int port, const std::string& output_path) const {
  SocketRuntime runtime;

  const SocketHandle socket_handle = socket(AF_INET, SOCK_STREAM, 0);
  if (socket_handle == kInvalidSocket) {
    throw std::runtime_error("failed to create TCP socket");
  }

  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_port = htons(static_cast<uint16_t>(port));
  address.sin_addr.s_addr = htonl(INADDR_ANY);

  const int reuse_addr = 1;
  setsockopt(socket_handle, SOL_SOCKET, SO_REUSEADDR, reinterpret_cast<const char*>(&reuse_addr),
             sizeof(reuse_addr));

  if (bind(socket_handle, reinterpret_cast<sockaddr*>(&address), sizeof(address)) != 0) {
    close_socket(socket_handle);
    throw std::runtime_error("failed to bind TCP socket");
  }

  if (listen(socket_handle, 8) != 0) {
    close_socket(socket_handle);
    throw std::runtime_error("failed to listen on TCP socket");
  }

  std::cout << "listening for live snapshots on TCP port " << port << '\n';

  for (;;) {
    sockaddr_in source_address{};
    socklen_t source_length = sizeof(source_address);
    const SocketHandle client_socket =
        accept(socket_handle, reinterpret_cast<sockaddr*>(&source_address), &source_length);
    if (client_socket == kInvalidSocket) {
      continue;
    }

    try {
      handle_snapshot_connection(client_socket, output_path);
      close_socket(client_socket);
    } catch (const std::exception& error) {
      close_socket(client_socket);
      std::cerr << "live render failed: " << error.what() << '\n';
    }
  }
}

bool LiveSyncServer::receive_once_and_render_tcp(const int port,
                                                 const std::string& output_path,
                                                 const int timeout_ms) const {
  SocketRuntime runtime;

  const SocketHandle socket_handle = socket(AF_INET, SOCK_STREAM, 0);
  if (socket_handle == kInvalidSocket) {
    throw std::runtime_error("failed to create TCP socket");
  }

  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_port = htons(static_cast<uint16_t>(port));
  address.sin_addr.s_addr = htonl(INADDR_ANY);

  const int reuse_addr = 1;
  setsockopt(socket_handle, SOL_SOCKET, SO_REUSEADDR, reinterpret_cast<const char*>(&reuse_addr),
             sizeof(reuse_addr));

  if (bind(socket_handle, reinterpret_cast<sockaddr*>(&address), sizeof(address)) != 0) {
    close_socket(socket_handle);
    throw std::runtime_error("failed to bind TCP socket");
  }

  if (listen(socket_handle, 1) != 0) {
    close_socket(socket_handle);
    throw std::runtime_error("failed to listen on TCP socket");
  }

  fd_set read_set;
  FD_ZERO(&read_set);
  FD_SET(socket_handle, &read_set);
  timeval timeout{};
  timeout.tv_sec = timeout_ms / 1000;
  timeout.tv_usec = (timeout_ms % 1000) * 1000;
  const int select_result =
      select(static_cast<int>(socket_handle) + 1, &read_set, nullptr, nullptr, &timeout);
  if (select_result <= 0) {
    close_socket(socket_handle);
    return false;
  }

  sockaddr_in source_address{};
  socklen_t source_length = sizeof(source_address);
  const SocketHandle client_socket =
      accept(socket_handle, reinterpret_cast<sockaddr*>(&source_address), &source_length);
  close_socket(socket_handle);
  if (client_socket == kInvalidSocket) {
    return false;
  }

  const std::string payload = read_snapshot_payload(client_socket);
  if (payload.empty()) {
    send_all_to_socket(client_socket, "ERR empty-payload\n");
    close_socket(client_socket);
    return false;
  }

  try {
    write_rendered_json_to_wav(payload, output_path);
    send_all_to_socket(client_socket, "OK rendered\n");
  } catch (const std::exception& error) {
    send_all_to_socket(client_socket, std::string("ERR ") + error.what() + "\n");
    close_socket(client_socket);
    throw;
  }

  close_socket(client_socket);
  return true;
}

}  // namespace spatial_preview
