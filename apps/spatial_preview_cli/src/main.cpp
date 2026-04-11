#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>

#include "spatial_preview/LiveSyncServer.hpp"
#include "spatial_preview/MathTypes.hpp"
#include "spatial_preview/OfflineRenderCommand.hpp"
#include "spatial_preview/ProjectLoader.hpp"
#include "spatial_preview/TrajectoryEvaluator.hpp"

namespace spatial_preview {

namespace {

void print_usage() {
  std::cout
      << "Usage:\n"
      << "  spatial_preview_cli summary <project.json>\n"
      << "  spatial_preview_cli eval <project.json> <time_sec>\n"
      << "  spatial_preview_cli sample <project.json> <step_sec>\n"
      << "  spatial_preview_cli render <project.json> <output.wav>\n"
      << "  spatial_preview_cli watch-render <project.json> <output.wav>\n"
      << "  spatial_preview_cli tcp-render <output.wav> <port>\n"
      << "  spatial_preview_cli tcp-render-once <output.wav> <port> <timeout_ms>\n";
}

void print_transform(const std::string& label, const Transform& transform) {
  std::cout << label << " position=" << to_string(transform.position)
            << " rotation_deg=" << to_string(transform.rotation_euler_deg) << '\n';
}

void run_summary(const Project& project) {
  std::cout << "title=" << project.metadata.title << '\n';
  std::cout << "duration_sec=" << std::fixed << std::setprecision(3) << project.metadata.duration_sec
            << '\n';
  std::cout << "sample_rate=" << project.metadata.sample_rate << '\n';
  std::cout << "tempo_bpm=" << project.metadata.tempo_bpm << '\n';
  std::cout << "listener_id=" << project.listener.id << '\n';
  std::cout << "listener_keys=" << project.listener.track.keys.size() << '\n';
  std::cout << "sources=" << project.sources.size() << '\n';
  for (const auto& source : project.sources) {
    std::cout << "source id=" << source.id << " asset=" << source.audio_asset
              << " gain_db=" << source.gain_db << " keys=" << source.track.keys.size() << '\n';
  }
}

void run_eval(const Project& project, const double time_sec) {
  const TrajectoryEvaluator evaluator;
  std::cout << "time_sec=" << std::fixed << std::setprecision(3) << time_sec << '\n';
  print_transform("listener", evaluator.evaluate(project.listener.track, time_sec));
  for (const auto& source : project.sources) {
    print_transform("source[" + source.id + "]", evaluator.evaluate(source.track, time_sec));
  }
}

void run_sample(const Project& project, const double step_sec) {
  if (step_sec <= 0.0) {
    throw std::runtime_error("step_sec must be > 0");
  }

  const TrajectoryEvaluator evaluator;
  for (double t = 0.0; t <= project.metadata.duration_sec + 1e-9; t += step_sec) {
    std::cout << "time_sec=" << std::fixed << std::setprecision(3) << t << '\n';
    print_transform("listener", evaluator.evaluate(project.listener.track, t));
    for (const auto& source : project.sources) {
      print_transform("source[" + source.id + "]", evaluator.evaluate(source.track, t));
    }
  }
}

}  // namespace

}  // namespace spatial_preview

int main(int argc, char** argv) {
  using namespace spatial_preview;

  if (argc < 2) {
    print_usage();
    return EXIT_FAILURE;
  }

  const std::string command = argv[1];

  try {
    if (command == "tcp-render") {
      if (argc < 4) {
        throw std::runtime_error("tcp-render requires <output.wav> <port>");
      }
      LiveSyncServer().listen_and_render_tcp(std::stoi(argv[3]), argv[2]);
      return EXIT_SUCCESS;
    }

    if (command == "tcp-render-once") {
      if (argc < 5) {
        throw std::runtime_error("tcp-render-once requires <output.wav> <port> <timeout_ms>");
      }
      const bool received = LiveSyncServer().receive_once_and_render_tcp(
          std::stoi(argv[3]), argv[2], std::stoi(argv[4]));
      if (!received) {
        std::cerr << "error: tcp-render-once timed out\n";
        return EXIT_FAILURE;
      }
      return EXIT_SUCCESS;
    }

    if (argc < 3) {
      throw std::runtime_error("missing required path argument");
    }

    const std::string path = argv[2];

    if (command == "render") {
      if (argc < 4) {
        throw std::runtime_error("render requires <output.wav>");
      }
      OfflineRenderCommand().render_project_to_wav(path, argv[3]);
      return EXIT_SUCCESS;
    }

    if (command == "watch-render") {
      if (argc < 4) {
        throw std::runtime_error("watch-render requires <output.wav>");
      }
      OfflineRenderCommand().watch_and_render(path, argv[3]);
      return EXIT_SUCCESS;
    }

    const ProjectLoader loader;
    const Project project = loader.load(path);

    if (command == "summary") {
      run_summary(project);
      return EXIT_SUCCESS;
    }

    if (command == "eval") {
      if (argc < 4) {
        throw std::runtime_error("eval requires <time_sec>");
      }
      run_eval(project, std::stod(argv[3]));
      return EXIT_SUCCESS;
    }

    if (command == "sample") {
      if (argc < 4) {
        throw std::runtime_error("sample requires <step_sec>");
      }
      run_sample(project, std::stod(argv[3]));
      return EXIT_SUCCESS;
    }

    throw std::runtime_error("unknown command: " + command);
  } catch (const std::exception& error) {
    std::cerr << "error: " << error.what() << '\n';
    return EXIT_FAILURE;
  }
}
