set(WOULDYOU_STEAM_AUDIO_INCLUDE_DIR "${PROJECT_SOURCE_DIR}/third_party/steam_audio/steamaudio/include")

if (WIN32)
  set(WOULDYOU_STEAM_AUDIO_LIB "${PROJECT_SOURCE_DIR}/third_party/steam_audio/steamaudio/lib/windows-x64/phonon.lib")
  set(WOULDYOU_STEAM_AUDIO_RUNTIME "${PROJECT_SOURCE_DIR}/third_party/steam_audio/steamaudio/lib/windows-x64/phonon.dll")
elseif(UNIX AND NOT APPLE)
  set(WOULDYOU_STEAM_AUDIO_LIB "${PROJECT_SOURCE_DIR}/third_party/steam_audio/steamaudio/lib/linux-x64/libphonon.so")
endif()

set(WOULDYOU_HAVE_STEAM_AUDIO OFF)
if (WOULDYOU_ENABLE_STEAM_AUDIO AND EXISTS "${WOULDYOU_STEAM_AUDIO_INCLUDE_DIR}/phonon.h" AND EXISTS "${WOULDYOU_STEAM_AUDIO_LIB}")
  set(WOULDYOU_HAVE_STEAM_AUDIO ON)
endif()

add_executable(spatial_preview_cli
  src/AudioAssetRegistry.cpp
  src/Json.cpp
  src/LiveSyncServer.cpp
  src/MiniaudioIO.cpp
  src/OfflineRenderCommand.cpp
  src/ProjectLoader.cpp
  src/SpatialPreviewRenderer.cpp
  src/TrajectoryEvaluator.cpp
  src/main.cpp
)

target_include_directories(spatial_preview_cli
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${PROJECT_SOURCE_DIR}/third_party/miniaudio/include
)

if (WOULDYOU_HAVE_STEAM_AUDIO)
  target_include_directories(spatial_preview_cli PRIVATE "${WOULDYOU_STEAM_AUDIO_INCLUDE_DIR}")
  target_compile_definitions(spatial_preview_cli PRIVATE WOULDYOU_HAS_STEAM_AUDIO=1)
  target_link_libraries(spatial_preview_cli PRIVATE "${WOULDYOU_STEAM_AUDIO_LIB}")

  if (UNIX AND NOT APPLE)
    set_target_properties(spatial_preview_cli PROPERTIES
      BUILD_RPATH "${PROJECT_SOURCE_DIR}/third_party/steam_audio/steamaudio/lib/linux-x64"
    )
  endif()

  if (WIN32 AND EXISTS "${WOULDYOU_STEAM_AUDIO_RUNTIME}")
    add_custom_command(TARGET spatial_preview_cli POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${WOULDYOU_STEAM_AUDIO_RUNTIME}"
        "$<TARGET_FILE_DIR:spatial_preview_cli>/phonon.dll"
    )
  endif()
endif()

if (MSVC)
  target_compile_options(spatial_preview_cli PRIVATE /W4 /permissive-)
else()
  target_compile_options(spatial_preview_cli PRIVATE -Wall -Wextra -Wpedantic)
endif()
