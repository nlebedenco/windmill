include(CMakePrintHelpers)

########################################################################################################################
# Configuration
########################################################################################################################
cmake_path(APPEND CMAKE_FOLDER "Desktop")

########################################################################################################################
# Sources
########################################################################################################################
include_directories("${CMAKE_CURRENT_SOURCE_DIR}")

# DO NOT use a glob to add all subdirectories because the order may be signficant. For example, library folders must be
# added before executables that depend on them.
add_subdirectory(windmill)
