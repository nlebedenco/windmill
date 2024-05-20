include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

include(CMakeDependentOption)
include(CheckIPOSupported)

# Enable interprocedural optimization (IPO/LTO) if supported.
check_ipo_supported(RESULT supported)

# For GCC this adds -flto -fno-fat-lto-objects to the targets.
# For MSVC this adds /GL and /LTCG
# See https://gitlab.kitware.com/cmake/cmake/-/issues/18189
# For clang-cl this add -flto=thin
cmake_dependent_option(CMAKE_INTERPROCEDURAL_OPTIMIZATION "" ON supported OFF)
mark_as_advanced(CMAKE_INTERPROCEDURAL_OPTIMIZATION)

# Disable LTO in debug builds as they may display unexpected behaviour and might be particularly tricky to debug.
# See https://trofi.github.io/posts/218-debugging-LTO-builds.html
cmake_dependent_option(CMAKE_INTERPROCEDURAL_OPTIMIZATION_DEBUG "" OFF supported OFF)
mark_as_advanced(CMAKE_INTERPROCEDURAL_OPTIMIZATION_DEBUG)

unset(supported)
