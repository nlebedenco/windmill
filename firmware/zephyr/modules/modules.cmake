cmake_minimum_required(VERSION 3.25)

# This file is configured in embedded/zephyr/module.yml as the entry point for external modules and it is included by
# Zephyr early on in the build configuration.
include_guard(DIRECTORY)
message(STATUS "Including modules.cmake file ${CMAKE_CURRENT_LIST_FILE}")

include(CMakePrintHelpers)

########################################################################################################################
# Definitions
########################################################################################################################
# Directory with our custom CMake modules
cmake_path(SET WINDMILL_MODULES_DIR NORMALIZE "${CMAKE_CURRENT_LIST_DIR}/../../../cmake/modules")

# CMake configurations shared between Desktop and Embedded projects
cmake_path(SET WINDMILL_SHARED_CMAKE_FILE NORMALIZE "${CMAKE_CURRENT_LIST_DIR}/../../../cmake/shared.cmake")

########################################################################################################################
# Options
########################################################################################################################
# Default build type
set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "")

########################################################################################################################
# Configuration
########################################################################################################################
# Update CMake include path to find our CMake modules.
if (DEFINED CMAKE_MODULE_PATH)
    set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH}")
endif ()
if (NOT "${WINDMILL_MODULES_DIR}" IN_LIST CMAKE_MODULE_PATH)
    list(APPEND CMAKE_MODULE_PATH "${WINDMILL_MODULES_DIR}")
endif ()

include(Windmill/Functions)

# Declare scope variables that are initialized with the value of a cache variable of the same name (if any).
windmill_declare_variables(
        CMAKE_FOLDER
        CMAKE_MODULE_PATH
        CMAKE_PREFIX_PATH
        CMAKE_PROGRAM_PATH
        CMAKE_INCLUDE_PATH
        CMAKE_LIBRARY_PATH
        CMAKE_FIND_ROOT_PATH
)

cmake_path(APPEND CMAKE_FOLDER "Embedded")

# Check that the generator is supported.
# Zephyr only supports Ninja and Makefile single-config generators.
get_property(multiconfig GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if (((NOT "${CMAKE_GENERATOR}" STREQUAL "Ninja") AND (NOT "${CMAKE_GENERATOR}" MATCHES "Makefiles")) OR multiconfig)
    message(FATAL_ERROR "Invalid generator: \"${CMAKE_GENERATOR}\""
            "(zephyr only supports Ninja and Makefile single-config generators)")
endif ()
unset(multiconfig)

# Zephyr manages compiler and linker flags using custom target properties under targets `compiler` and `compiler-cpp`
# but CMake is unaware of that and will try to automatically initialize compiler flag variables for the standard build
# types. Later these initial values are appended with Zephyr generated flags which is undesirable because Zephyr will
# end up either duplicating or overriding flags introduced by CMake which can only contribute to confuse developers.
# (e.g. adding -O2 after CMake already added -O3 on the same command line).
#
# Set default compiler flags to empty to avoid potentially conflicting options - which will happen when C and CXX
# languages are first enabled by the declaration of project(Zephyr-kernel). Manually-specified variables remain
# unaffected.
foreach (lang IN ITEMS C CXX)
    foreach (suffix IN ITEMS "" _DEBUG _RELEASE _RELWITHDEBINFO _MINSIZEREL)
        set(CMAKE_${lang}_FLAGS${suffix} "" CACHE STRING "")
    endforeach ()
endforeach ()

# When a build type is defined but the corresponding CMake compiler flags variable is empty it is safe to disable
# Zephyr warnings about a potential mismatch with optimization flags coming from Kconfig.
string(TOUPPER "_${CMAKE_BUILD_TYPE}" suffix)
if ("${CMAKE_C_FLAGS${suffix}}" STREQUAL "")
    set(NO_BUILD_TYPE_WARNING ON)
endif ()
unset(suffix)

# Set Kconfig optimization option defaults based on CMAKE_BUILD_TYPE.
#
# NOTE: Zephyr always compiles with debug information regardless of the optimization level because debug symbols are
#       stripped from the elf file when it gets converted into a bin image. Normally, the zephyr.bin file (or its
#       corresponding hex file) is the bootable image and the only file required to flash but it is possible to obtain a
#       copy of zephyr.elf with debugging information removed by setting CONFIG_BUILD_OUTPUT_STRIPPED=y. By default, the
#       stripped ELF file is named zephyr.strip.
#
#       See https://devzone.nordicsemi.com/f/nordic-q-a/81868/zephyr-compiled-with-debug-data-despite-setting-config_optimize_speed-y
#
if ("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    set(CONFIG_DEBUG y CACHE INTERNAL "")
    set(CONFIG_DEBUG_OPTIMIZATIONS y CACHE INTERNAL "")
elseif ("${CMAKE_BUILD_TYPE}" STREQUAL "Release")
    set(CONFIG_SPEED_OPTIMIZATIONS y CACHE INTERNAL "")
    set(CONFIG_BUILD_OUTPUT_STRIPPED y CACHE INTERNAL "")
    add_compile_definitions(NDEBUG)
elseif ("${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo")
    set(CONFIG_DEBUG y CACHE INTERNAL "")
    set(CONFIG_SPEED_OPTIMIZATIONS y CACHE INTERNAL "")
    add_compile_definitions(NDEBUG)
elseif ("${CMAKE_BUILD_TYPE}" STREQUAL "MinSizeRel")
    set(CONFIG_SIZE_OPTIMIZATIONS y CACHE INTERNAL "")
    set(CONFIG_BUILD_OUTPUT_STRIPPED y CACHE INTERNAL "")
endif ()

add_compile_options($<$<NOT:$<BOOL:${CONFIG_DEBUG}>>:-DNDEBUG>)

# Set Kconfig color diagnostics option default based on CMAKE_COLOR_DIAGNOSTICS.
if (DEFINED CMAKE_COLOR_DIAGNOSTICS)
    set(value n)
    if (CMAKE_COLOR_DIAGNOSTICS)
        set(value y)
    endif ()
    set(CONFIG_COMPILER_COLOR_DIAGNOSTICS "${value}" CACHE INTERNAL "")
    unset(value)
    # Unset CMAKE_COLOR_DIAGNOSTICS so CMake does not add a redundant compiler. Let Zephyr add one if needed.
    unset(CMAKE_COLOR_DIAGNOSTICS)
    unset(CMAKE_COLOR_DIAGNOSTICS CACHE)
endif ()

# HACK: Inject the script with common configuration steps between Desktop and Embedded. This is the same script we
#       include for desktop, and CMake should include it right after the call to project(Zephyr-Kernel). Ideally, Zephyr
#       could provide a variable similar to zephyr_cmake_modules for CMake modules to be added AFTER the call to
#       include(kernel).
windmill_declare_variables(CMAKE_PROJECT_Zephyr-Kernel_INCLUDE)
list(APPEND CMAKE_PROJECT_Zephyr-Kernel_INCLUDE "${WINDMILL_SHARED_CMAKE_FILE}")

########################################################################################################################
# Static Code Analysis
########################################################################################################################
# HACK: Codechecker is not well supported on Windows and cannot handle paths with double backslash. This is due to in
#       part to how it relies on `shlex.split` which cannot handle Windows paths. We can abuse Zephyr's global property
#       "extra_post_build_commands" to setup a custom command that will copy compile_commands.json and replace all
#       occurences of double backslash with slash in compile_commands.json.
#       See https://bugs.python.org/issue1724822
#       See https://github.com/mesonbuild/meson/issues/5726
#       See https://stackoverflow.com/q/69909487
#       See https://stackoverflow.com/a/35900070
#       See https://gitlab.kitware.com/cmake/cmake/-/issues/25580
if ("${ZEPHYR_SCA_VARIANT}" STREQUAL "codechecker" AND "${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows")
    find_package(Python3 REQUIRED COMPONENTS Interpreter) # just for sanity, should have been found already
    cmake_path(SET filename NORMALIZE "${CMAKE_CURRENT_LIST_DIR}/scripts/fix_double_backslashes.py")
    set_property(GLOBAL APPEND PROPERTY extra_post_build_commands
            COMMAND "${Python3_EXECUTABLE}"
            ARGS "${filename}" "${CMAKE_BINARY_DIR}/compile_commands.json")
    unset(filename)
endif ()

########################################################################################################################
# Find Extra Modules
########################################################################################################################
# The modules.cmake file must contain the logic that specifies the integration files for Zephyr modules via specifically
# named CMake variables.
#
# To include a module's CMake file, set the variable ZEPHYR_<MODULE_NAME>_CMAKE_DIR to the path containing the CMake
# file.
file(GLOB cmake_modules "${CMAKE_CURRENT_LIST_DIR}/*/CMakeLists.txt ")

foreach (module ${cmake_modules})
    get_filename_component(dir "${module}" DIRECTORY)
    get_filename_component(name "${dir}" NAME)
    zephyr_string(SANITIZE TOUPPER name "${name}")
    set(ZEPHYR_${name}_CMAKE_DIR "${dir}")
    unset(name)
    unset(dir)
endforeach ()
unset(cmake_modules)

# To include a module's Kconfig file, set the variable ZEPHYR_<MODULE_NAME>_KCONFIG to the path to the Kconfig file.
file(GLOB kconfig_modules " ${CMAKE_CURRENT_LIST_DIR}/*/Kconfig ")

foreach (module ${kconfig_modules})
    get_filename_component(dir "${module}" DIRECTORY)
    get_filename_component(name "${dir}" NAME)
    zephyr_string(SANITIZE TOUPPER name "${name}")
    set(ZEPHYR_${name}_KCONFIG "${dir}/Kconfig")
    unset(name)
    unset(dir)
endforeach ()
unset(kconfig_modules)
