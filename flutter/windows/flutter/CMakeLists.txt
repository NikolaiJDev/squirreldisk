# This file controls Flutter-level build steps. It should not be edited.
cmake_minimum_required(VERSION 3.14)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Configuration provided via flutter tool.
include(${EPHEMERAL_DIR}/generated_config.cmake)

# For more information about ephemeral directories and generated files, see:
# https://docs.flutter.dev/release/breaking-changes/windows-cmake-project-file-structure

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${EPHEMERAL_DIR}")

# Flutter install
set(FLUTTER_INSTALL_DIR "${EPHEMERAL_DIR}")
if(CMAKE_HOST_WIN32)
  set(FLUTTER_ROOT "${FLUTTER_INSTALL_DIR}")
else()
  set(FLUTTER_ROOT "${FLUTTER_INSTALL_DIR}")
endif()

# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(${EPHEMERAL_DIR}/generated_plugins.cmake)