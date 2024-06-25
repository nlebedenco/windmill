cmake_minimum_required(VERSION 3.25)

# This file is included right after the calls to project(Zephyr-Kernel) and project(WINDMILL_DESKTOP)
include_guard(DIRECTORY)
message(STATUS "Including shared.cmake file ${CMAKE_CURRENT_LIST_FILE}")

include(CMakePrintHelpers)
include(CMakeDependentOption)

########################################################################################################################
# Definitions
########################################################################################################################
if (NOT DEFINED WINDMILL_NAME)
    set(WINDMILL_NAME WINDMILL)
endif ()

if (NOT DEFINED WINDMILL_SOURCE_DIR)
    cmake_path(SET WINDMILL_SOURCE_DIR NORMALIZE "${CMAKE_CURRENT_LIST_DIR}/..")
endif ()

if (NOT DEFINED WINDMILL_BINARY_DIR)
    set(WINDMILL_BINARY_DIR "${CMAKE_BINARY_DIR}")
endif ()

# Read version information
file(STRINGS "${WINDMILL_SOURCE_DIR}/VERSION" WINDMILL_VERSION LIMIT_COUNT 1)
string(REGEX REPLACE "^([0-9]+).*$" "\\1" WINDMILL_VERSION_MAJOR "${WINDMILL_VERSION}")
string(REGEX REPLACE "^[0-9]+.([0-9]+).*$" "\\1" WINDMILL_VERSION_MINOR "${WINDMILL_VERSION}")
string(REGEX REPLACE "^[0-9]+.[0-9]+.([0-9]+).*$" "\\1" WINDMILL_VERSION_PATCH "${WINDMILL_VERSION}")

# Directory for building packages.
set(WINDMILL_TEMPLATES_DIR "${WINDMILL_SOURCE_DIR}/cmake/templates")

# Directory with submodules sources.
set(WINDMILL_PACKAGES_SOURCE_DIR "${WINDMILL_SOURCE_DIR}/submodules")

# Directory for building packages.
set(WINDMILL_PACKAGES_BINARY_DIR "${WINDMILL_BINARY_DIR}/submodules")

# Directory for building packages.
set(WINDMILL_GENERATED_DIR "${WINDMILL_BINARY_DIR}/generated")

# CMake config header template.
set(WINDMILL_CONFIG_H_IN "${WINDMILL_TEMPLATES_DIR}/config.h.in")

# CMake config header.
set(WINDMILL_CONFIG_H "${WINDMILL_GENERATED_DIR}/windmill/config.h")

# Command to copy DLLs with corresponding PDBs
set(WINDMILL_COMMAND_DLLCOPY "${Python3_EXECUTABLE}" -u "${WINDMILL_SOURCE_DIR}/extras/python/dllcopy.py")

# Command wrapper for source code linters (iwyu, clang-tidy, ...)
set(WINDMILL_COMMAND_LINTER "${Python3_EXECUTABLE}" -u "${WINDMILL_SOURCE_DIR}/extras/python/linter.py")


########################################################################################################################
# Options
########################################################################################################################
# This option lets the compiler make aggressive, potentially-lossy assumptions about floating-point math such as:
#
#    - Floating-point math obeys regular algebraic rules for real numbers (e.g. + and * are associative) so that
#      x/y == x * (1/y), and (a + b) * c == a * c + b * c;
#
#    - Operands to floating-point operations are not equal to NaN and Inf;
#
#    - +0 and -0 are interchangeable
#
# Normally, many optimizations are prevented by properties of the floating-point values NaN, Inf, and -0.0. For example:
#
#     - x + 0.0 cannot be optimized to x because that is not true when x is -0.0.
#
#     - x - x cannot be optimized to 0.0 because that is not true when x is NaN or Inf.
#
#     - x * 0.0 cannot be optimized to 0.0 because that is not true when x is NaN or Inf.
#
# Enabling fast math tells the compiler that no calculation will produce NaN, Inf, or -0.0, so it [the compiler] is free
# to perform those optimizations.
#
# In particular, associative math allows re-ordering of operands in a series of floating-point operations (as well as a
# few more general reordering optimizations). This is relevant because strict IEEE754 floating-point operations are
# not even commutative. For example, using a Python REPL we can easily verify that:
#
#     >>> (.1 + .2) + .3
#     0.6000000000000001
#     >>> .1 + (.2 + .3)
#     0.6
#     >>> (.1 * .2) * .3
#     0.006000000000000001
#     >>> .1 * (.2 * .3)
#     0.006
#
# Some examples of associative math optimizations:
#
# Original	            | Optimized
# ----------------------|--------
# (X + Y) - X	        | Y
# (X * Z) + (Y * Z)	    | (X + Y) * Z
# (X * C) + X	        | X * (C + 1.0)     when C is a constant
# (C1 / X) * C2	        | (C1 * C2) / X     when C1 and C2 are constants
# (C1 - X) < C2	        | (C1 - C2) > X     when C1 and C2 are constants
#
# Re-association is especially useful for vectorization.
# See https://kristerw.github.io/2021/10/19/fast-math/
# See https://simonbyrne.github.io/notes/fastmath/
option(WINDMILL_ENABLE_FAST_MATH "Enable fast math floating point optimizations" ON)

cmake_dependent_option(WINDMILL_ENABLE_GCC_ANALYZER "Enable static analysis for the GNU compiler (C code only)" OFF
        "CMAKE_C_COMPILER_ID MATCHES \"^(GNU)$\"" OFF)

cmake_dependent_option(WINDMILL_ENABLE_CLANG_TIDY "Enable static analysis for the Clang compiler" OFF
        "CMAKE_C_COMPILER_ID MATCHES \"^(GNU|Clang|AppleClang)$\"" OFF)

option(WINDMILL_CLANG_TIDY_WARNING_AS_ERROR "Specify whether to treat clang-tidy warnings as errors" OFF)

option(WINDMILL_ENABLE_CPPCHECK "Enable static analysis with cppcheck" ON)
option(WINDMILL_CPPCHECK_WARNING_AS_ERROR "Specify whether to treat clang-tidy warnings as errors" OFF)

# Default additional checks for Cppcheck
# Errors are always reported but additional checks can be enabled using the following ids:
#
#   - all: Enable all messages.
#
#   - style: Enable messages with severities 'style', 'warning', 'performance' and 'portability'.
#
#   - warning: Enable earning messages
#
#   - performance: Enable performance messages
#
#   - portability: Enable portability messages
#
#   - information: Enable information messages
#
#   - unusedFunction: Check for unused functions.
#
#   - missingInclude:  Warn if there are missing includes.
#
# Multiple ids may be selected using a comma-separated list.
set(WINDMILL_CPPCHECK_CHECKS "style" CACHE STRING "Enable additional checks for Cppcheck")
set_property(CACHE WINDMILL_CPPCHECK_CHECKS PROPERTY STRINGS "all;style;warning;performance;portability;information;unusedFunction;missingInclude")

cmake_dependent_option(WINDMILL_ENABLE_IWYU "Enable static analysis with include-what-you-use" ON
        "CMAKE_C_COMPILER_ID MATCHES \"^(GNU|Clang|AppleClang)$\"" OFF)

option(WINDMILL_IWYU_WARNING_AS_ERROR "Specify whether to treat include-what-you-use warnings as errors" OFF)

option(WINDMILL_BUILD_PACKAGES "Build packages in the configuration phase" ON)
option(WINDMILL_STAGE_PACKAGES "Stage packages in the configuration phase" ON)
option(WINDMILL_COPY_SYSTEM_LIBS "Copy system libraries after build" OFF)

cmake_dependent_option(WINDMILL_ENABLE_SEMANTIC_INTERPOSITION
        "Enable semantic interposition for binaries linked with position independent code (PIC)" OFF
        "CMAKE_SYSTEM_NAME MATCHES \"^(Linux|Darwin)$\"" OFF)

# There is no support for shared libraries in the Zephyr system.
# Refer to Zephyr's Linkable Loadable Extensions (LLEXT) for a potential alternative.
cmake_dependent_option(BUILD_SHARED_LIBS "Build shared libraries by default" OFF
        "CMAKE_SYSTEM_NAME MATCHES \"^(Windows|Linux|Darwin)$\"" OFF)

# Default directory for pre-compiled package archives.
set(WINDMILL_PACKAGES_DIR "${WINDMILL_SOURCE_DIR}/packages" CACHE PATH "Directory with pre-compiled package archives")
mark_as_advanced(WINDMILL_PACKAGES_DIR)

# Default directory to extract pre-compiled package archives.
set(WINDMILL_STAGE_DIR "${WINDMILL_SOURCE_DIR}/.stage" CACHE PATH "Directory to extract pre-compiled package archives")
mark_as_advanced(WINDMILL_STAGE_DIR)

########################################################################################################################
# Report
########################################################################################################################
message(STATUS "Project: ${WINDMILL_NAME} ${WINDMILL_VERSION}")

site_name(WINDMILL_HOST_NAME)
message(STATUS "Local machine name: ${WINDMILL_HOST_NAME}")

string(TIMESTAMP WINDMILL_HOST_TIME)
message(STATUS "Local machine time: ${WINDMILL_HOST_TIME}" UTC)

message(STATUS "GCC Analyzer (only for GNU compiler and C code): ${WINDMILL_ENABLE_GCC_ANALYZER}")
message(STATUS "Clang-Tidy (only for Clang compiler): ${WINDMILL_ENABLE_CLANG_TIDY}")
message(STATUS "Cppcheck: ${WINDMILL_ENABLE_CPPCHECK}")
message(STATUS "Include-what-you-use: ${WINDMILL_ENABLE_IWYU}")

message(STATUS "Build shared libraries by default: ${BUILD_SHARED_LIBS}")
message(STATUS "Build packages in the configuration phase: ${WINDMILL_BUILD_PACKAGES}")
message(STATUS "Stage packages in the configuration phase: ${WINDMILL_STAGE_PACKAGES}")
message(STATUS "Copy system libraries after build: ${WINDMILL_COPY_SYSTEM_LIBS}")

message(STATUS "Semantic interposition for binaries linked with position independent code (PIC): ${WINDMILL_ENABLE_SEMANTIC_INTERPOSITION}")

########################################################################################################################
# Configuration
########################################################################################################################
# Ensure try_compile can find custom CMake modules in particular Platform/Zephyr. This is important for some CMake
# functions that use try_compile indirectly such as `check_ipo_supported()`.
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES CMAKE_MODULE_PATH)

include(Windmill/Generators)
include(Windmill/Compilers)
include(Windmill/Systems)
include(Windmill/Features/InterproceduralOptimization)
include(Windmill/Features/PositionIndependentCode)

# At this point the following variables should be defined and cannot be modified any further:
#
#     - CMAKE_HOST_SYSTEM_NAME          : manually-specified or automatically determined by CMake
#     - CMAKE_HOST_SYSTEM_VERSION       : manually-specified or automatically determined by CMake
#     - CMAKE_HOST_SYSTEM_PROCESSOR     : manually-specified or automatically determined by CMake
#
#     - WINDMILL_HOST_SYSTEM_PLATFORM     : "APPLE" on Apple systems; "PC" for x86/x86_64/arm64 on non-Apple;
#                                         anything else is unsupported and raises a fatal error
#     - WINDMILL_HOST_SYSTEM_ABI          : determined based on CMAKE_HOST_SYSTEM_NAME
#     - WINDMILL_HOST_SYSTEM_ABI_VERSION  : determined based on WINDMILL_HOST_SYSTEM_ABI
#
#     - CMAKE_SYSTEM_NAME               : manually-specified, set by toolchain file or automatically determined by CMake
#     - CMAKE_SYSTEM_VERSION            : manually-specified, set by toolchain file or automatically determined by CMake
#     - CMAKE_SYSTEM_PROCESSOR          : manually-specified, set by toolchain file or automatically determined by CMake
#
#     - WINDMILL_SYSTEM_PLATFORM          : defaults to "Apple" on Apple systems; "PC" for x86/x86_64/arm64 on non-Apple
#                                         systems; the value of BOARD for generic systems; else "Unknown"
#     - WINDMILL_SYSTEM_ABI               : determined based on CMAKE_SYSTEM_NAME, defaults to CMAKE_C_COMPILER_ID
#     - WINDMILL_SYSTEM_ABI_VERSION       : determined based on WINDMILL_SYSTEM_ABI
#
windmill_require_variables(
        # CMake host system variables
        CMAKE_HOST_SYSTEM_NAME
        CMAKE_HOST_SYSTEM_VERSION
        CMAKE_HOST_SYSTEM_PROCESSOR
        # Windmill host system variables
        WINDMILL_HOST_SYSTEM_PLATFORM
        WINDMILL_HOST_SYSTEM_ABI
        WINDMILL_HOST_SYSTEM_ABI_VERSION
        # CMake target system variables
        CMAKE_SYSTEM_NAME
        CMAKE_SYSTEM_VERSION
        CMAKE_SYSTEM_PROCESSOR
        # Windmill target system variables
        WINDMILL_SYSTEM_PLATFORM
        WINDMILL_SYSTEM_ABI
        WINDMILL_SYSTEM_ABI_VERSION
)

if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Android")
    windmill_require_variables(
            CMAKE_ANDROID_ARCH
            CMAKE_ANDROID_ARCH_ABI
    )
endif ()

# A canonical triplet is formed by the concatenation of <processor>, <platform>, <system name> and <abi>.
# All canonical triplets should be lower case and do not carry any version information. If needed, version information
# should be obtained from the corresponding variable (e.g. CMAKE_SYSTEM_VERSION for the target system version and
# WINDMILL_SYSTEM_ABI_VERSION for the target system ABI version). If version information is missing (e.g. empty or
# undefined) it should be considered as "0.0.0". We ignore any pre-defined value (manually-specified or not) to ensure
# the triple is always consistent with the base variables used to determine it.
windmill_triplet(
        PROCESSOR "${CMAKE_HOST_SYSTEM_PROCESSOR}"
        PLATFORM "${WINDMILL_HOST_SYSTEM_PLATFORM}"
        NAME "${CMAKE_HOST_SYSTEM_NAME}"
        ABI "${WINDMILL_HOST_SYSTEM_ABI}"
        OUTPUT_VARIABLE WINDMILL_HOST_SYSTEM_TRIPLET
)

if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Android")
    windmill_triplet(
            PROCESSOR "${CMAKE_ANDROID_ARCH}"
            PLATFORM "${WINDMILL_SYSTEM_PLATFORM}"
            NAME "${CMAKE_SYSTEM_NAME}"
            ABI "${WINDMILL_SYSTEM_ABI}"
            OUTPUT_VARIABLE WINDMILL_SYSTEM_TRIPLET
    )
else ()
    windmill_triplet(
            PROCESSOR "${CMAKE_SYSTEM_PROCESSOR}"
            PLATFORM "${WINDMILL_SYSTEM_PLATFORM}"
            NAME "${CMAKE_SYSTEM_NAME}"
            ABI "${WINDMILL_SYSTEM_ABI}"
            OUTPUT_VARIABLE WINDMILL_SYSTEM_TRIPLET
    )
endif ()

windmill_warn_cache_variables_overriden(
        WINDMILL_HOST_SYSTEM_TRIPLET
        WINDMILL_SYSTEM_TRIPLET
)

message(STATUS "Host system name: ${CMAKE_HOST_SYSTEM_NAME}")
message(STATUS "Host system version: ${CMAKE_HOST_SYSTEM_VERSION}")
message(STATUS "Host system processor: ${CMAKE_HOST_SYSTEM_PROCESSOR}")

message(STATUS "Host system platform: ${WINDMILL_HOST_SYSTEM_PLATFORM}")
message(STATUS "Host system ABI: ${WINDMILL_HOST_SYSTEM_ABI}")
message(STATUS "Host system ABI version: ${WINDMILL_HOST_SYSTEM_ABI_VERSION}")
message(STATUS "Host system triplet: ${WINDMILL_HOST_SYSTEM_TRIPLET}")

message(STATUS "Target system name: ${CMAKE_SYSTEM_NAME}")
message(STATUS "Target system version: ${CMAKE_SYSTEM_VERSION}")
message(STATUS "Target system processor: ${CMAKE_SYSTEM_PROCESSOR}")

if (APPLE)
    message(STATUS "Target system deployment version: ${CMAKE_OSX_DEPLOYMENT_TARGET}")
endif ()

message(STATUS "Target system platform: ${WINDMILL_SYSTEM_PLATFORM}")
message(STATUS "Target system ABI: ${WINDMILL_SYSTEM_ABI}")
message(STATUS "Target system ABI version: ${WINDMILL_SYSTEM_ABI_VERSION}")
message(STATUS "Target system triplet: ${WINDMILL_SYSTEM_TRIPLET}")

# Selected Windows SDK is only reported by the Visual Studio generators.
# Supposedly, both VS and Ninja will select the latest one installed by default.
if (WINDOWS AND "${CMAKE_GENERATOR}" MATCHES "Visual Studio")
    message(STATUS "Selected Windows SDK: ${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION}")
endif ()

message(STATUS "Position independent code: ${CMAKE_POSITION_INDEPENDENT_CODE}")
message(STATUS "Interprocedural optimization: ${CMAKE_INTERPROCEDURAL_OPTIMIZATION}")
foreach (config IN LISTS CMAKE_CONFIGURATION_TYPES)
    string(TOUPPER "CMAKE_INTERPROCEDURAL_OPTIMIZATION_${config}" variable)
    if (DEFINED ${variable})
        message(STATUS "Interprocedural optimization for ${config}: ${${variable}}")
    endif ()
    unset(variable)
endforeach ()

# Add paths for staging package archives with pre-compiled artifacts. Package archives have a unique base name and
# include a manifest file <name>.json with information about the sources and a list of all the files packed (including
# the manifest itself). The structure of a pre-compiled package archive mirrors a GNU directory structure and we place
# optional <config> builds under /opt as follows:
#
#     <triplet>
#      |____ <name>.json
#      |____ bin
#      |____ lib
#      |____ include
#      |____ etc
#      |____ share
#      |____ opt
#             |____ <config>
#             .      |____ bin
#             .      |____ lib
#             .
#
# Default build type for packages is Release, so all folders under <triplet> should be considered release files. Other
# build types are optional and must be placed under their corresponding <triplet>/opt/<config> folder. Notice that
# include headers and shared files are assumed to be common to all build types so <triplet>/opt/<config> should only
# contain bin and lib sub-folders.
#
# We CANNOT simply set CMAKE_PREFIX_PATH here because programs must be searched under the HOST triplet while building
# artifacts (headers, libraries, etc) must be searched based on the TARGET triplet which might NOT be the same, for
# example, when cross-compiling. Finding non-Release artifacts then requires a complete path in the PATHS argument
# associated with a ONLY_CMAKE_FIND_ROOT_PATH  to avoid unintended matches from regular search paths. For example:
#
#     find_library(ZLIB_LIBRARY_DEBUG
#             NAMES z zlib
#             NAMES_PER_DIR
#             PATH_SUFFIXES "opt/debug/lib"
#             ONLY_CMAKE_FIND_ROOT_PATH
#             )
#
# Notice that CMake cannot normally build for different HOST and TARGET in the same instance because only one compiler
# may be configured. Therefore CMAKE_LIBRARY_PATH and CMAKE_INCLUDE_PATH should never have to be used to find build
# artifacts for the HOST specifically. In particular cases of cross-compilation (HOST != TARGET) where find_file() and
# find_path() should locate files for the HOST system, we have to explicitly pass NO_CMAKE_FIND_ROOT_PATH.
if (NOT "${CMAKE_SYSTEM_NAME}" STREQUAL "Zephyr")
    list(APPEND CMAKE_INCLUDE_PATH /include)
    list(APPEND CMAKE_LIBRARY_PATH /lib)
endif ()
list(APPEND CMAKE_PROGRAM_PATH "${WINDMILL_STAGE_DIR}/${WINDMILL_HOST_SYSTEM_TRIPLET}/bin")
# Append the python executable folder in case it is from a virtual environment where we can find other host tools.
if (EXISTS "${Python3_EXECUTABLE}")
    cmake_path(GET Python3_EXECUTABLE PARENT_PATH path)
    list(APPEND CMAKE_PROGRAM_PATH "${path}")
    unset(path)
endif ()
list(APPEND CMAKE_FIND_ROOT_PATH "${WINDMILL_STAGE_DIR}/${WINDMILL_SYSTEM_TRIPLET}")

# Disable warnings for external headers.
# This configuration depends on WINDMILL_SYSTEM_TRIPLET to be defined so it cannot go into Windmill/Compilers/Common.
foreach (lang IN ITEMS C CXX)
    if ("${CMAKE_${lang}_COMPILER_ID}" MATCHES "^(GNU|Clang|AppleClang)")
        if (DEFINED CMAKE_${lang}_STANDARD_INCLUDE_DIRECTORIES)
            set(CMAKE_${lang}_STANDARD_INCLUDE_DIRECTORIES "${CMAKE_${lang}_STANDARD_INCLUDE_DIRECTORIES}")
        endif ()
        list(APPEND CMAKE_${lang}_STANDARD_INCLUDE_DIRECTORIES "${WINDMILL_STAGE_DIR}/${WINDMILL_SYSTEM_TRIPLET}/include")
    endif ()
endforeach ()

# Compiler definitions for build type
add_compile_definitions(
        WINDMILL_BUILD_TYPE=\"$<CONFIG>\"
        WINDMILL_CONFIG_$<UPPER_CASE:$<CONFIG>>=1
)

########################################################################################################################
# Pre-compiled packages
########################################################################################################################
# Packages provide dependency information to CMake and are tipically resolved with the find_package() function. The
# result of using find_package() is either a set of IMPORTED targets, or a set of variables corresponding to
# build-relevant information (see https://cmake.org/cmake/help/v3.22/manual/cmake-packages.7.html)
#
# For this particular project, we expand on what CMake calls FindModule-packages by using pre-compiled package archives
# stored in the WINDMILL_PACKAGES_DIR folder. This is meant to solve:
#     1. Long build times in particular when host-only tools are involved that are not normally shipped by any of the
#        supported host platforms (Windows, Linux and macOS);
#     2. Lack of control over dependencies including precise version tracking, known build parameters and strict link
#        rules. We would like to have all these explicitly controlled and clearly verifiable rather than reyling on
#        whatever might be provided by the host system, target system or toolchain's sysroot.
#
# Package archives are built by `Packages.<Package>` targets. Some package targets, however, can only be built for
# the host system and will fail if the target system is not the host (i.e cross-compiling). Packages are therefore tied
# to a target system triplet, a build script (Build<Package>.cmake) and a find script (Find<Package>.cmake)
# both located in the WINDMILL_MODULES_DIR folder. Package archives are only decompressed in the WINDMILL_STAGE_DIR when
# necessary. The staging function is smart enough to determine if source references in WINDMILL_PACKAGES_SOURCE_DIR have
# changed in order to trigger a re-build.
#
# This is not supposed to be a general purpose depedency management system which encompasses far more complex problems
# than the ones we are actually trying to solve. Pre-compiled packages are subject to the following limitations:
#
#     - Packages for the host cannot be cross-compiled. For example, we cannot build a tool like include-what-you-use
#       for Windows on a Linux host. This is due to the fact that:
#           1. A host system package is only relevant for the running host and will never produce artifacts used to
#              build the target system unless both host and target systems are the same;
#           2. CMake can only build for a single system configuration at once so in order to build a package for the
#              host system (e.g. tools) the target system MUST be the host system.
#
#     - The same dependency version must be used across all target systems. This is a trade off between simplicity,
#       traceability and reproducibility versus flexibility. And it is not exactly a limitation of the packaging
#       mechanism but a consequence of using git submodules to track down dependencies as opposed to on-demand
#       download/caching of 3rd party source trees. A pre-compiled package in this context is simply a headstart for
#       something that would have been compiled into the project anyway without much or any change in every build.
#       Use of git submodules is great because it gives a clear picture of what is bundled with the project at ANY POINT
#       in the development history out-of-the-box. But if we really want to force different verions of the same
#       dependency (submodule) for different target systems we have to somehow bypass git and automate submodule
#       synchronization as an extra extra step and give up that clear association between git histories (ours and the
#       dependency's). In fact, the submodule commit point stored in our history might be even be misleading because our
#       build scripts could be forcing another point one altogether depending on the target system. Tracking all this
#       down can get pretty confusing pretty fast and is terrible for code audits.
#
#     - The same dependency version is used across all project modules. This is similar to the previous limitation and
#       may sound obvious now but it can be particularly challenging if an artifact (lib or exe) has a lot of nested
#       dependencies or the nesting is deep into other 3rd party dependencies. For example, our project depends on 3rd
#       party projects A-1.0 and B-1.0 but B-1.0 itself depends on A-2.0. This problem can be particular nasty if we are
#       linking to static libraries as it can cause symbol redefinitions or inconsistent function implementations.
#       Fortunately, this not a common case for embedded applications and careful consideration of 3rd party
#       dependencies will help to address it. We always have a choice of replacing a dependency (under our
#       control/relatively easy option), bump the required version in our project to match (under our control/might be
#       an even easier option) or patch the 3rd party that introduced the mismatched (partially under our control via
#       fork-branching/more difficult).
#
#     - The version indicated in the package declaration via windmill_declare_package() is treated as a minimum required
#       and meat as a safe-guard against accidental mix-and-match. It has no effect on the submodule's folder content.
#       Note that a package may need to be built multiple times for the same platform in different ABI versions
#       (e.g. multiple glibc versions). Backward compatibililty for package versions and ABI versions is always presumed
#       so if a minimum required version is 1.0 we simply assume that any version greater or equal to 1.0 is equally
#       good, be it 1.2, 2.0 or 3.0. It is up to the developer to make sure the submodule reference is appropriate and
#       the package archive stored in the repository (if any) is valid and accurate. In case of multiple package
#       matches the staging function will select the package with the latest ABI version that satisfies the build.
#
#     - All package names are case-sensitive and must match the name of the corresponding Build<Package>.cmake and
#       Find<Package>.cmake files in WINDMILL_MODULES_DIR.
#
#     - All package names once converted to lower case may correspond to a folder in WINDMILL_PACKAGES_SOURCE_DIR, so all
#       submodule folders in WINDMILL_PACKAGES_SOURCE_DIR MUST BE comprised only of alphanumeric lower-case characters
#       (i.e. [0-9,a-z]). The same lower-case name is used to compose the name of the package archive stored in
#       WINDMILL_PACKAGES_DIR. As a side effect, all package names must be case-insensitively unique.
#
# Should any of these limitations ever become a barrier we might consider using an open-source dependency manager
# solution such as vcpkg or conan.io. Beware though that general purpose solutions as these never come without a whole
# set of additional restrictions, configuration requirements, side-effects, potential bugs AND limited support since
# they only cover major desktop platforms out-of-the box. And in practice we are still left to write custom build
# scripts in a way or another for dependencies.
# See https://cmake.org/cmake/help/v3.22/manual/cmake-packages.7.html#find-module-packages

# Set minimum required version for packages. This will also build and archive missing packages or packages whose sources
# have been modified unless building is explicitly disallowed by NO_BUILD or -DWINDMILL_BUILD_PACKAGE_<Package>=OFF.
windmill_declare_package(GIT 2.30 HOST NO_BUILD)
windmill_declare_package(ClangTidy 17.0 HOST NO_BUILD)
if (WINDMILL_ENABLE_CPPCHECK)
    windmill_declare_package(PCRE 8.45.0 HOST) # Cppcheck dependency only, targets should use PCRE2
    windmill_declare_package(Cppcheck 2.13.0 HOST)
endif ()
if (WINDMILL_ENABLE_IWYU)
    windmill_declare_package(IWYU 0.21 HOST) # 0.12 is equivalent to clang 17.x
endif ()

########################################################################################################################
# Analyzers
########################################################################################################################
include(Windmill/Analyzers/ClangTidy)
include(Windmill/Analyzers/CppCheck)
include(Windmill/Analyzers/IWYU)
include(Windmill/Analyzers/GCC)

########################################################################################################################
# Header generation
########################################################################################################################
message(STATUS "Generating CMake header: ${WINDMILL_CONFIG_H}")
configure_file("${WINDMILL_CONFIG_H_IN}" "${WINDMILL_CONFIG_H}" FILE_PERMISSIONS OWNER_READ GROUP_READ WORLD_READ)

include_directories("${WINDMILL_GENERATED_DIR}")
