# This project is structured in a peculiar way because of how Zephyr integrates with CMake. West may be used to build
# firmware applications but we still want to be able to build using a top-level CMakeLists.txt to remain IDE friendly.
# The way Zephyr supports custom modules configured via module.yml and how external modules get injected in the build
# may also seem counter-intuitive for developers used to a canonical CMake project structure.
#
# In a high level, the configuration process can be described as follows:
#
#     Enter <PROJECT_ROOT_DIR> (top-level CMakeLists.txt)
#         Declare top-level project (no languages)
#             Include <PROJECT_ROOT_DIR>/cmake/toolchains/<CMAKE_SYSTEM_NAME>.cmake (optional)
#         Configure python environment (default location is <PROJECT_ROOT_DIR>/.venv/<CMAKE_HOST_SYSTEM_NAME>)
#         if <CMAKE_SYSTEM_NAME> is "Generic"
#             Configure west workspace
#                 Download west dependencies into <PROJECT_ROOT_DIR>/.west
#         if <CMAKE_SYSTEM_NAME> is "Generic"
#             Enter <PROJECT_ROOT_DIR>/firmware/zephyr/apps/<appname>
#                 Include <PROJECT_ROOT_DIR>/firmware/zephyr/modules/modules.cmake
#                 Generate zephyr.dts
#                 Generate devicetree_generated.h
#                 Include generated dts.cmake
#                 Parse <PROJECT_ROOT_DIR>/firmware/zephyr/apps/<appname>/Kconfig
#                     Include <PROJECT_ROOT_DIR>/firmware/zephyr/Kconfig
#                         Include <PROJECT_ROOT_DIR>/firmware/zephyr/drivers/Kconfig
#                         Include <PROJECT_ROOT_DIR>/firmware/zephyr/lib/Kconfig
#                 Generate .config
#                 Generate autoconf.h
#                 Declare Zephyr-Kernel project
#                     Enable Languages C CXX
#                         Detect C and CXX compilers
#                     Include sca.cmake file (optional) - e.g. <PROJECT_ROOT_DIR>/firmware/zephyr/cmake/sca/cppcheck/sca.cmake
#                 Include <PROJECT_ROOT_DIR>/cmake/shared.cmake
#                 Enter <PROJECT_ROOT_DIR>/firmware/zephyr
#                     Enter <PROJECT_ROOT_DIR>/firmware/zephyr/drivers
#                     Enter <PROJECT_ROOT_DIR>/firmware/zephyr/lib
#                 Declare firmware project
#                     Add sources for target 'app'
#         else
#             Enter <PROJECT_ROOT_DIR>/platforms
#                 if <CMAKE_SYSTEM_NAME> matches "Windows", "Linux" or "Darwin"
#                     Enter <PROJECT_ROOT_DIR>/platforms/desktop
#                     Declare desktop project
#                         Enable Languages C CXX
#                     Include <PROJECT_ROOT_DIR>/cmake/shared.cmake
#                     Enter <PROJECT_ROOT_DIR>/platforms/desktop/windmill
#                         Enter <PROJECT_ROOT_DIR>/platforms/desktop/windmill/empty
#                           Add sources for target 'empty'
#                 else if <CMAKE_SYSTEM_NAME> matches "Android", "iOS",  "tvOS", "watchOS" or "visionOS"
#                     Enter <PROJECT_ROOT_DIR>/platforms/mobile
#                     Declare desktop project
#                         Enable Languages C CXX
#                     Include <PROJECT_ROOT_DIR>/cmake/shared.cmake
#                     Enter <PROJECT_ROOT_DIR>/platforms/mobile/windmill
#                         Enter <PROJECT_ROOT_DIR>/platforms/mobile/windmill/empty
#                           Add sources for target 'empty'
#                 endif
#         endif
#
# Our top-level CMakeLists.txt decides what to configure based on <CMAKE_SYSTEM_NAME>. A value of "Generic" refers
# to firmware while anything else (at least for now) refers to general applications (desktop/mobile).
#
# If using West to build directly from a firmware source folder (or a .west/zephyr/samples folder) the configuration
# process becomes just this fragment:
#
#     Enter <PROJECT_ROOT_DIR>/firmware/zephyr/apps/<appname>
#         Include <PROJECT_ROOT_DIR>/firmware/zephyr/modules/modules.cmake
#         Generate zephyr.dts
#         Generate devicetree_generated.h
#         Include generated dts.cmake
#         Parse <PROJECT_ROOT_DIR>/firmware/zephyr/apps/<appname>/Kconfig
#             Include <PROJECT_ROOT_DIR>/firmware/zephyr/Kconfig
#                 Include <PROJECT_ROOT_DIR>/firmware/zephyr/drivers/Kconfig
#                 Include <PROJECT_ROOT_DIR>/firmware/zephyr/lib/Kconfig
#         Generate .config
#         Generate autoconf.h
#         Declare Zephyr-Kernel project
#             Enable Languages C CXX
#                 Detect C and CXX compilers
#         Include sca.cmake file (optional) - e.g. <PROJECT_ROOT_DIR>/firmware/zephyr/cmake/sca/cppcheck/sca.cmake
#         Include <PROJECT_ROOT_DIR>/cmake/shared.cmake
#         Enter <PROJECT_ROOT_DIR>/firmware/zephyr
#             Enter <PROJECT_ROOT_DIR>/firmware/zephyr/drivers
#             Enter <PROJECT_ROOT_DIR>/firmware/zephyr/lib
#         Declare firmware project
#             Add sources for target 'app'
#
# Zephyr build scripts will look for CMake modules of a given ZEPHYR_SCA_VARIANT under user modules first and only if
# not found will fall back to the ones in the Zephyr source tree.
#
# Note that, in both examples example above, when configuring a firmware, <PROJECT_ROOT_DIR>/firmware/zephyr is treated
# by CMake as a subdirectory of <PROJECT_ROOT_DIR>/firmware/zephyr/apps/<appname> regardless of their real locations in
# the file system. Therefore, it is <PROJECT_ROOT_DIR>/firmware/zephyr that inherits scope variables from
# <PROJECT_ROOT_DIR>/firmware/zephyr/apps/<appname> and not the other way around.
#
# Also note that when using West to build directly from the firmware source folder we have to assume that a python
# environment has been previously created, activated and updated by the user with all the necessary requirements.
#
# In terms of structure, CMake list files are organized in layers each with a set of responsibilities and restrictions
# as follows:
#
# <PROJECT_ROOT>
#     |____ CMakeLists.txt: Environment set up (python virtual environment, west workspace). Cannot enforce any build
#     |                     rule since it is effectively bypassed when building a Zephyr application using West.
#     |
#     |____ cmake
#     |       |___ toolchains
#     |       |       |____ <CMAKE_SYTEM_NAME>
#     |       |               |___ Rules
#     |       |               |      |____ <CMAKE_<LANG>_COMPILER>.cmake: Basic compiler configuration
#     |       |               |
#     |       |               |___ <CMAKE_<LANG>_COMPILER>.cmake: Fundamental target system configuration and
#     |       |                                                   compiler detection.
#     |       |___ modules
#     |       |       |____ Windmill
#     |       |               |___ Generators.cmake: CMake generator configurations and checks
#     |       |               |___ Compilers.cmake: Dynamic compiler configurations and checks
#     |       |               |___ Systems.cmake: Dynamic system configurations and checks
#     |       |
#     |       |____ shared.cmake: Configuration shared between Zephyr and non-zephyr applications (acts like a virtual
#     |                           top-level CMake lists). Build rules can be enforced here.
#     |
#     |____ firmware
#     |       |____ zephyr
#     |               |____ modules.cmake: Configuration exclusive to Zephyr applications.
#     |
#     |____ platforms
#             |____ CMakeLists.txt: Configuration shared by non-Zephyr applications
#             |
#             |____ desktop
#             |       |____ CMakeLists.txt: Configuration for desktop applications only
#             |
#             |____ mobile
#                     |____ CMakeLists.txt: Configuration for mobile applications only
#
# Note that standard support for static code analysis in both CMake and Zephyr is deficient in many ways which is why
# we implement custom find modules for clang-tidy, include-what-you-use (iwyu) and cppcheck. In particular:
#
#   - `Clang-Tidy` integration in CMake only fully works when the configured compiler is also Clang. It can tolerate
#     some GNUC or CL (msvc) compiler options to some degree and might even seem to work for simple configurations
#     but will break at the first optimization option that is unknown to Clang;
#
#   - `GCC analyzer` can only be configured with compiler options that become part of the build and all issues are
#     reported as special compiler warnings which makes it more complicated to exclude thrid-party sources from the
#     verification and does not play well with compiler cache tools (e.g. ccache);
#
#   - `Sparse` requires custom source code annotations;
#
#   - `cpptest` is proprietary and requires a commercial license from Parasoft;
#
#   - `Cppcheck` is mostly restricted to pattern matching and so is prone to false positives;
#
#   - `CodeChecker` is extremely cumbersome to configure, must run as a separate build target, always analyzes all
#     sources known by the build system even those not used in the build; does not produce IDE friendly output
#     (generates a lot of text noise), does not support Windows and requires an underlying analyzer to be specified
#     since it is just a wrapper. Analyzers supported in version 6.23.1 are:
#         - Clang Tidy
#         - Clang Static Analyzer
#         - Cppcheck
#         - GCC Static Analyzer (requires GCC >=13)
#     See https://github.com/Ericsson/codechecker/issues/555
#     See https://github.com/Ericsson/codechecker/issues/4032
#     See https://codechecker.readthedocs.io/en/latest/supported_code_analyzers/
#
# On top of all that, by-design Zephyr only supports one SCA tool per configuration.
#
# Also note that although the Zephyr project claims to support a number of different toolchains only the Zephyr SDK is
# actively verified and tested. In addition, the majority of Zephyr scripts assume the compiler is GCC or has a GCC
# frontend.
#
# See https://github.com/zephyrproject-rtos/zephyr/issues/63738
# See https://github.com/zephyrproject-rtos/zephyr/issues/32111
#

########################################################################################################################
# Preamble
########################################################################################################################
# The cmake_minimum_required(VERSION) command implicitly calls cmake_policy(VERSION) so there is no need to set
# individual policies unless an OLD behaviour is required for some special reason (which should be avoided anyway!).
# See https://cmake.org/cmake/help/latest/command/cmake_policy.html#setting-policies-by-cmake-version
cmake_minimum_required(VERSION 3.25)

# Forbid in-source builds.
# NOTE: DO NOT rely on CMAKE_DISABLE_IN_SOURCE_BUILD or CMAKE_DISABLE_SOURCE_CHANGES here as they are likely to be
#       modified or removed any time.
#       See https://gitlab.kitware.com/cmake/cmake/-/issues/18403#note_604138
if (EXISTS "${CMAKE_BINARY_DIR}/CMakeLists.txt")
    # Remove CMakeCache.txt and the CMakeFiles folder that are auto-generated by CMake before this check.
    file(REMOVE_RECURSE
            "${CMAKE_SOURCE_DIR}/CMakeCache.txt"
            "${CMAKE_SOURCE_DIR}/CMakeFiles/"
    )
    message(FATAL_ERROR "This project will not build correctly in the source directory."
            "Please use an empty binary directory for that.")
endif ()

# Acquire a lock of the source tree for the rest of the configuration phase to prevent two CMake instances from
# modifying shared folders such as python environment and package staging directory.
#
# NOTE: Lock is advisory; there is no guarantee that other processes will respect this lock, i.e. synchronize two or
#       more CMake instances sharing some modifiable resources. Similar logic applies to the DIRECTORY option; locking a
#       parent directory doesn't prevent other LOCK commands from locking any child directory or file.
#       See https://cmake.org/cmake/help/latest/command/file.html#lock
#
# FIXME: File locking in a Windows native instance is ignored in WSL2 (broken?) which means it cannot mutually exclude
#        CMake instances running in a Windows host and in WSL2. The only workaround for now is to avoid configuring the
#        project on Windows native and in WSL2 at the same time. In CLion make sure to check
#       "Reload CMake profiles sequentially" unde Settings->Advanced Settings->CMake
#        See https://github.com/microsoft/WSL/issues/5762
file(LOCK "${CMAKE_CURRENT_SOURCE_DIR}/.lock" DIRECTORY GUARD PROCESS)

# Update CMake include path to find our CMake modules.
if (DEFINED CMAKE_MODULE_PATH)
    set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH}")
endif ()
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules")

include(CMakePrintHelpers)
include(CMakeDependentOption)

########################################################################################################################
# Definitions
########################################################################################################################
# Directory with git index files (if this is a top-level git repository)
set(WINDMILL_GIT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.git")

# Directory with the west manifest.
set(WINDMILL_WEST_MANIFEST_DIR "${CMAKE_CURRENT_SOURCE_DIR}/embedded")

# Requirements file for the python environment
set(WINDMILL_PYTHON_REQUIREMENTS_TXT "${CMAKE_CURRENT_SOURCE_DIR}/extras/requirements.txt")

########################################################################################################################
# Project
########################################################################################################################
# We are forced to declare a project here because CMake requires the root CMakeLists.txt to have one but by explicitly
# specifying LANGUAGES NONE we can skip compiler detection altogether. Note, however, that a toolchain file, if defined
# by CMAKE_TOOLCHAIN_FILE, will be included by this call.
project(WINDMILL LANGUAGES NONE)

# Default to export compile_commands.json used by clangd, clang-tidy, cppcheck and codechecker.
# This option is implemented only by Makefile Generators and Ninja Generators. It is ignored on other generators.
# This option currently does not work well in combination with the UNITY_BUILD target property or the CMAKE_UNITY_BUILD
# variable.
# See https://cmake.org/cmake/help/latest/variable/CMAKE_EXPORT_COMPILE_COMMANDS.html
option(CMAKE_EXPORT_COMPILE_COMMANDS "Generate a compiler database file (compile_commands.json)" ON)
mark_as_advanced(CMAKE_EXPORT_COMPILE_COMMANDS)

# Default to use color diagnostics. CLion always adds the CMAKE_COLOR_DIAGNOSTICS=ON environment variable when
# re-loading the CMake project so the best we can do is make it behave the same on the command-line as well.
# NOTE: Zephyr ignores CMAKE_COLOR_DIAGNOSTICS and controls compiler diagnostics only based on Kconfig options which
#       means that when CMAKE_COLOR_DIAGNOSTICS=ON and
option(CMAKE_COLOR_DIAGNOSTICS "" ON)
mark_as_advanced(CMAKE_COLOR_DIAGNOSTICS)

# Default to NOT add the current source and build dir of each directory into the include path by default.
option(CMAKE_INCLUDE_CURRENT_DIR "" OFF)
mark_as_advanced(CMAKE_INCLUDE_CURRENT_DIR)

# Default to warn if CMake implicitly assumes Config mode in find_package() because of missing find modules.
# This variable has no effect if CMAKE_FIND_PACKAGE_PREFER_CONFIG is set to TRUE.
option(CMAKE_FIND_PACKAGE_WARN_NO_MODULE "Warn when find_package() implicitly assumes Config mode." ON)
mark_as_advanced(CMAKE_FIND_PACKAGE_WARN_NO_MODULE)

# Default to treat compiler warnings as errors by default
option(CMAKE_COMPILE_WARNING_AS_ERROR "Specify whether to treat warnings on compile as errors." ON)
mark_as_advanced(CMAKE_COMPILE_WARNING_AS_ERROR)

# Use the FOLDER target property to organize targets into folders.
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Default name of folder used to group predefined targets in the Visual Studio solution.
set(CMAKE_PREDEFINED_TARGETS_FOLDER "CMakePredefinedTargets" CACHE STRING "")
mark_as_advanced(CMAKE_PREDEFINED_TARGETS_FOLDER)

# Put ALL_BUILD, INSTALL and ZERO_CHECK projects in a separate solution folder in VisualStudio.
# This will not affect other IDEs such as Xcode and CLion.
set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER "${CMAKE_PREDEFINED_TARGETS_FOLDER}")

# Adjust the default behavior of the find_xxx() commands.
# Search for headers and libraries in the target environment; search for programs in the host environment.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER CACHE STRING "")
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY CACHE STRING "")
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY CACHE STRING "")
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY CACHE STRING "")

# Adjust the folder name used to organize targets in some IDEs.
# Force a scope variable in case CMAKE_FOLDER was previously defined as a cache variable.
if (DEFINED CMAKE_FOLDER)
    set(CMAKE_FOLDER "${CMAKE_FOLDER}")
endif ()
cmake_path(APPEND CMAKE_FOLDER "Windmill")

########################################################################################################################
# Options
########################################################################################################################
option(WINDMILL_CONFIGURE_PYTHON_ENVIRONMENT "Configure python virtual environment" ${PROJECT_IS_TOP_LEVEL})
option(WINDMILL_CONFIGURE_WEST_WORKSPACE "Configure west workspace" ${PROJECT_IS_TOP_LEVEL})
option(WINDMILL_CONFIGURE_PRE_COMMIT "Configure pre-commit hooks" ${PROJECT_IS_TOP_LEVEL})

# Default directory for the python environment. It is more convenient to have the virtual environment located in
# the source directory than in the build directory because it depends only on the host system and in the source
# directory it can be shared between multiple configurations. We still append CMAKE_HOST_SYSTEM_NAME to the path
# to support the the use case of configuring targets for Windows native and WSL in the same machine using presets.
set(WINDMILL_PYTHON_VENV_DIR "${CMAKE_SOURCE_DIR}/.venv/${CMAKE_HOST_SYSTEM_NAME}" CACHE PATH
        "Directory with the python virtual environment")
mark_as_advanced(WINDMILL_PYTHON_VENV_DIR)

# Default firmware project to build when the target system is "Generic". Must be safe for any board.
if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Generic")
    # This CACHE type must be STRING and not PATH otherwise relative paths are made absolute based on CMAKE_BINARY_DIR.
    set(FIRMWARE "firmware/zephyr/apps/example_empty" CACHE STRING "")
    mark_as_advanced(FIRMWARE)
endif ()

########################################################################################################################
# Report
########################################################################################################################
message(STATUS "Configure Python environment: ${WINDMILL_CONFIGURE_PYTHON_ENVIRONMENT}")
message(STATUS "Configure West workspace: ${WINDMILL_CONFIGURE_WEST_WORKSPACE}")
message(STATUS "Configure pre-commit hooks: ${WINDMILL_CONFIGURE_PRE_COMMIT}")

########################################################################################################################
# Python
########################################################################################################################
# On Windows, instruct Python to output UTF-8 even when not interacting with a terminal. This is required since
# Python scripts are invoked by CMake code and, on Windows, standard I/O encoding defaults to the current code page
# if not connected to a terminal, which is often not what we want.
if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows" AND NOT DEFINED ENV{PYTHONIOENCODING})
    set(ENV{PYTHONIOENCODING} "utf-8")
endif ()

# Version range required for python
# FIXME: Avoid Python 3.12 and superior for now due to issues with pip on Windows.
#        See https://github.com/Ericsson/codechecker/issues/4032
set(WINDMILL_PYTHON_VERSION_RANGE 3.9...<3.12)

# Configure python environment
if (WINDMILL_CONFIGURE_PYTHON_ENVIRONMENT)
    set(expected)
    if (DEFINED Python3_EXECUTABLE)
        set(expected "${Python3_EXECUTABLE}")
    endif ()

    # Find a python interpreter to start with.
    find_package(Python3 "${WINDMILL_PYTHON_VERSION_RANGE}" REQUIRED COMPONENTS Interpreter QUIET)

    # The expected python interpreter was not found so fallback to the default python environment folder for this host.
    if ("${Python3_EXECUTABLE}" PATH_EQUAL "${expected}")
        # Get the python base prefix
        execute_process(
                COMMAND "${Python3_EXECUTABLE}" -c "import sys; print(sys.prefix)"
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                OUTPUT_VARIABLE location
                OUTPUT_STRIP_TRAILING_WHITESPACE
                COMMAND_ERROR_IS_FATAL ANY
        )
        cmake_path(CONVERT "${location}" TO_CMAKE_PATH_LIST location)
        message(STATUS "Using python environment at ${location}")
    else ()
        set(location "${WINDMILL_PYTHON_VENV_DIR}")
        # Create python environment if it does not exist yet.
        if (EXISTS "${location}")
            message(STATUS "Using python environment at ${location}")
            # Unset the python interpreter used to create the python environment to find the correct one.
            # There is a chance Python3_EXECUTABLE already points to the correct executable if the user had the
            # VIRTUAL_ENV environment variable set to the default virtual env folder defined by VIRTUAL_ENV_DIR.
            cmake_path(IS_PREFIX location "${Python3_EXECUTABLE}" acceptable)
            if (NOT acceptable)
                unset(Python3_EXECUTABLE)
                unset(Python3_EXECUTABLE CACHE)
            endif ()
            unset(acceptable)
        else ()
            message(STATUS "Creating python environment at ${location}")
            execute_process(
                    COMMAND "${Python3_EXECUTABLE}" -m venv --upgrade-deps "${location}"
                    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                    COMMAND_ERROR_IS_FATAL ANY
            )
            # Unset the python interpreter used to create the python environment to find the correct one.
            unset(Python3_EXECUTABLE)
            unset(Python3_EXECUTABLE CACHE)
        endif ()

        # Find the python executable in our python environment
        find_program(Python3_EXECUTABLE
                NAMES python
                HINTS "${location}"
                PATH_SUFFIXES bin Scripts
                REQUIRED
                NO_DEFAULT_PATH
        )
    endif ()
    unset(Python3_Interpreter_FOUND)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)

    # Finally, check that the last python interpreter found is in fact from our python environment.
    execute_process(
            COMMAND "${Python3_EXECUTABLE}" -c "import sys; print(sys.prefix if sys.prefix != sys.base_prefix else '')"
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            OUTPUT_VARIABLE venvdir
            OUTPUT_STRIP_TRAILING_WHITESPACE
            COMMAND_ERROR_IS_FATAL ANY
    )
    cmake_path(CONVERT "${venvdir}" TO_CMAKE_PATH_LIST venvdir)
    if (NOT "${venvdir}" PATH_EQUAL "${location}")
        message(FATAL_ERROR "Invalid Python3 executable (parent path is \"${venvdir}\", but required is \"${location}\")")
    endif ()
    unset(venvdir)
    unset(expected)
    unset(location)

    # Update the python environment according to the python executable in use.
    message(CHECK_START "Configuring python environment with base requirements from ${WINDMILL_PYTHON_REQUIREMENTS_TXT}")
    file(SHA256 "${WINDMILL_PYTHON_REQUIREMENTS_TXT}" checksum)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${WINDMILL_PYTHON_REQUIREMENTS_TXT}")
    if (NOT WINDMILL_PYTHON_REQUIREMENTS_CONFIGURED)
        set(WINDMILL_PYTHON_REQUIREMENTS_CONFIGURED "" CACHE INTERNAL "")
    endif ()
    if ("${WINDMILL_PYTHON_REQUIREMENTS_CONFIGURED}" STREQUAL "${checksum}")
        message("No change to requirements in '${WINDMILL_PYTHON_REQUIREMENTS_TXT}'")
    else ()
        execute_process(
                COMMAND "${Python3_EXECUTABLE}" -m pip install --progress-bar off -r "${WINDMILL_PYTHON_REQUIREMENTS_TXT}"
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                COMMAND_ERROR_IS_FATAL ANY
        )
        set(WINDMILL_PYTHON_REQUIREMENTS_CONFIGURED "${checksum}" CACHE INTERNAL "")
    endif ()
    unset(checksum)
    message(CHECK_PASS "done")
else ()
    find_package(Python3 "${WINDMILL_PYTHON_VERSION_RANGE}" REQUIRED COMPONENTS Interpreter)
endif ()

########################################################################################################################
# West
########################################################################################################################
if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Generic")
    cmake_path(GET Python3_EXECUTABLE PARENT_PATH hints)
    find_program(West_EXECUTABLE NAMES west HINTS "${hints}" REQUIRED)
    unset(hints)
    message(STATUS "Found west: ${West_EXECUTABLE}")

    # Configure west workspace
    if (WINDMILL_CONFIGURE_WEST_WORKSPACE)
        # Get west workspace folder (if any)
        execute_process(
                COMMAND "${West_EXECUTABLE}" topdir
                OUTPUT_VARIABLE workspace
                ERROR_QUIET
                OUTPUT_STRIP_TRAILING_WHITESPACE
        )

        if (workspace)
            cmake_path(APPEND workspace ".west")
        else ()
            # Check that CMAKE_CURRENT_SOURCE_DIR is a prefix of WINDMILL_WEST_MANIFEST_DIR
            cmake_path(IS_PREFIX CMAKE_CURRENT_SOURCE_DIR "${WINDMILL_WEST_MANIFEST_DIR}" NORMALIZE ok)
            if (NOT ok)
                message(FATAL_ERROR "CMAKE_CURRENT_SOURCE_DIR must be a prefix of WINDMILL_WEST_MANIFEST_DIR")
            endif ()
            unset(ok)
            # Initialize west workspace
            cmake_path(SET workspace NORMALIZE "${WINDMILL_WEST_MANIFEST_DIR}/../.west")
            execute_process(
                    COMMAND "${West_EXECUTABLE}" init --local
                    WORKING_DIRECTORY "${WINDMILL_WEST_MANIFEST_DIR}"
                    COMMAND_ERROR_IS_FATAL ANY
            )
            # Set a default build dir that does not conflict with the default used in our CMakePresets.json so we can
            # invoke both West and CMake safely in the same comand line.
            execute_process(
                    COMMAND "${West_EXECUTABLE}" config build.dir-fmt ".build/west/{board}/{app}"
                    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                    COMMAND_ERROR_IS_FATAL ANY
            )
        endif ()
        Message(STATUS "Using west workspace at ${workspace}")
        unset(workspace)

        # Update west workspace.
        message(CHECK_START "Configuring west workspace")
        execute_process(
                COMMAND "${West_EXECUTABLE}" update
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                COMMAND_ERROR_IS_FATAL ANY
        )
        message(CHECK_PASS "done")

        # Get the zephyr base directory.
        execute_process(
                COMMAND "${West_EXECUTABLE}" list -f "{posixpath}" zephyr
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                OUTPUT_VARIABLE ZEPHYR_BASE
                OUTPUT_STRIP_TRAILING_WHITESPACE
                COMMAND_ERROR_IS_FATAL ANY
        )

        # Set environment variable to reflect the zephyr we want to use
        if (DEFINED ENV{ZEPHYR_BASE})
            if (NOT "$ENV{ZEPHYR_BASE}" STREQUAL "${ZEPHYR_BASE}")
                message(STATUS "Overriding ZEPHYR_BASE environment variable with the zephyr location reported by west (${ZEPHYR_BASE})")
            endif ()
        endif ()

        set(ENV{ZEPHYR_BASE} "${ZEPHYR_BASE}")

        # Update the python environment with zephyr requirements according to the python executable in use.
        set(WINDMILL_ZEPHYR_REQUIREMENTS_TXT "${ZEPHYR_BASE}/scripts/requirements.txt")
        if (EXISTS "${WINDMILL_ZEPHYR_REQUIREMENTS_TXT}")
            message(CHECK_START "Configuring python environment with zephyr requirements")
            file(SHA256 "${WINDMILL_ZEPHYR_REQUIREMENTS_TXT}" checksum)
            set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${WINDMILL_ZEPHYR_REQUIREMENTS_TXT}")
            if (NOT WINDMILL_ZEPHYR_REQUIREMENTS_CHECKSUM)
                set(WINDMILL_ZEPHYR_REQUIREMENTS_CHECKSUM "" CACHE INTERNAL "")
            endif ()
            if ("${WINDMILL_ZEPHYR_REQUIREMENTS_CHECKSUM}" STREQUAL "${checksum}")
                message("No change to requirements in '${WINDMILL_ZEPHYR_REQUIREMENTS_TXT}'")
            else ()
                execute_process(
                        COMMAND "${Python3_EXECUTABLE}" -m pip install --progress-bar off -r "${WINDMILL_ZEPHYR_REQUIREMENTS_TXT}"
                        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                        COMMAND_ERROR_IS_FATAL ANY
                )
                set(WINDMILL_ZEPHYR_REQUIREMENTS_CHECKSUM "${checksum}" CACHE INTERNAL "")
            endif ()
            unset(checksum)
            message(CHECK_PASS "done")
        endif ()
    endif ()
endif ()

########################################################################################################################
# Pre-Commit
########################################################################################################################
message(CHECK_START "Configuring pre-commit hooks")
if (IS_DIRECTORY "${WINDMILL_GIT_DIR}")
    cmake_path(GET Python3_EXECUTABLE PARENT_PATH hints)
    find_program(PRE_COMMIT_EXECUTABLE NAMES pre-commit HINTS "${hints}")
    unset(hints)

    set(failed 1)
    if (PRE_COMMIT_EXECUTABLE)
        if (WINDMILL_CONFIGURE_PRE_COMMIT)
            set(action install)
        else ()
            set(action uninstall)
        endif ()
        execute_process(
                COMMAND "${PRE_COMMIT_EXECUTABLE}" "${action}"
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                RESULT_VARIABLE failed
        )
        unset(action)
    else ()
        message(AUTHOR_WARNING "Could NOT find pre-commit (missing: PRE_COMMIT_EXECUTABLE)")
    endif ()
    if (failed)
        message(CHECK_FAIL "failed")
    else ()
        message(CHECK_PASS "done")
    endif ()
    unset(failed)
else ()
    message(CHECK_PASS "skipped (not a top-level git repository)")
endif ()

########################################################################################################################
# Sources
########################################################################################################################
# "Generic" is the target system name used by CMake to represent systems that are not supported out-of-the-box and need
# particular configurations (e.g. bare metal embedded devices).
if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Generic")
    # Add firmware sources
    # FIXME: Zephyr CMake scripts contains tons of uninitialized variables being referenced which raises multiple
    #        dev warnings when CMake is invoked with `--warn-uninitialized`. There is no way to disable uninitialized
    #        variable warnings only for Zephyr scripts but we can disable dev warnings in general with the
    #        CMAKE_SUPPRESS_DEVELOPER_WARNINGS cache variable. This is an undocummented variable that is set when CMake
    #        is invoked with "--Wno-dev". Unfortunately, use of uninitialized variables not considered an issue by the
    #        Zephyr project, in part because it is common practice  with Makefiles and shell scripts but also because
    #        the recommended practice of using Zephyr is to place it outside your project root and CMake only warns
    #        about uninitialized variables from scripts under the project root. This hack may be removed if/when Zephyr
    #        upstream stops using uninitialized variables.
    #        See https://stackoverflow.com/a/75161296
    #        See https://gitlab.kitware.com/cmake/cmake/-/issues/24409
    #        See https://gitlab.kitware.com/cmake/cmake/-/issues/19645
    set(restore IGNORE)
    if (DEFINED CACHE{CMAKE_SUPPRESS_DEVELOPER_WARNINGS})
        set(restore "$CACHE{CMAKE_SUPPRESS_DEVELOPER_WARNINGS}")
    endif ()
    set(CMAKE_SUPPRESS_DEVELOPER_WARNINGS ON CACHE INTERNAL "")

    add_subdirectory("${FIRMWARE}")

    if (restore)
        set(CMAKE_SUPPRESS_DEVELOPER_WARNINGS "${restore}" CACHE INTERNAL "")
    else ()
        unset(CMAKE_SUPPRESS_DEVELOPER_WARNINGS CACHE)
    endif ()
    unset(restore)

    string(REPLACE "/" "." target "${FIRMWARE}")
    add_custom_target("${target}" DEPENDS zephyr_final)
    add_custom_target("${target}.menuconfig" DEPENDS menuconfig)
    add_custom_target("${target}.guiconfig" DEPENDS guiconfig)
    unset(target)
else ()
    # Warn about passing BOARD and FIRMWARE in a desktop build. It is a common mistake to pass BOARD and FIRMWARE and
    # forget to pass -DCMAKE_SYSTEM_NAME=Zephyr
    set(unused "")
    foreach (variable IN ITEMS BOARD FIRMWARE)
        if (DEFINED CACHE{${variable}})
            list(APPEND unused "${variable}")
        endif ()
    endforeach ()
    if (unused)
        string(REPLACE ";" "\n  " unused "${unused}")
        message(WARNING "Manually-specified variables are not used when building for ${CMAKE_SYSTEM_NAME}:\n  ${unused}")
    endif ()
    unset(unused)

    add_subdirectory(platforms)
endif ()
