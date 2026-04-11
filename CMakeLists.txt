cmake_minimum_required(VERSION 3.20)

project(Wouldyou LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(WOULDYOU_ENABLE_STEAM_AUDIO "Enable Steam Audio backend when SDK files are present." ON)

add_subdirectory(apps/spatial_preview_cli)
