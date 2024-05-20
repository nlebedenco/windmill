include(Windmill/Functions)

windmill_stage_package(PCRE HOST)

set(PACKAGE_BUILD_TYPES Release)

# Clean build folders
file(REMOVE_RECURSE
        "${PACKAGE_BINARY_DIR}"
        "${PACKAGE_OUTPUT_DIR}"
)

foreach (PACKAGE_BUILD_TYPE IN LISTS PACKAGE_BUILD_TYPES)
    message(CHECK_START "Building ${PACKAGE_NAME} for ${WINDMILL_SYSTEM_TRIPLET} (${PACKAGE_BUILD_TYPE})")
    list(APPEND CMAKE_MESSAGE_INDENT "    ")

    # Build suffix for cmake variables
    string(TOUPPER "${PACKAGE_BUILD_TYPE}" PACKAGE_BUILD_SUFFIX)

    # Build directory passed to setup and build commands
    cmake_path(SET PACKAGE_BUILD_DIR NORMALIZE "${PACKAGE_BINARY_DIR}/${PACKAGE_BUILD_TYPE}")

    # Install directory passed in CMAKE_INSTALL_PREFIX
    set(PACKAGE_INSTALL_DIR "${PACKAGE_OUTPUT_DIR}")
    if (NOT PACKAGE_BUILD_TYPE STREQUAL "Release")
        string(TOLOWER "${PACKAGE_BUILD_TYPE}" folder)
        cmake_path(APPEND PACKAGE_INSTALL_DIR "opt" "${folder}")
        unset(folder)
    endif ()

    # Define setup command
    set(PACKAGE_COMMAND_SETUP
            "${CMAKE_COMMAND}"
            -G "${PACKAGE_GENERATOR}"
            -S "${PACKAGE_SOURCE_DIR}"
            -B "${PACKAGE_BUILD_DIR}"
            --no-warn-unused-cli
            # Disable CMake deprecation warnings we cannot fix
            "-DCMAKE_WARN_DEPRECATED=OFF"
            # Disable pre-compiled headers
            "-DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON"
            # Provide CMake basic build options
            "-DCMAKE_BUILD_TYPE=${PACKAGE_BUILD_TYPE}"
            "-DCMAKE_INSTALL_PREFIX=${PACKAGE_INSTALL_DIR}"
            # Force no shared libs
            "-DBUILD_SHARED_LIBS=OFF"
            # cppcheck options
            "-DREGISTER_TESTS=OFF"
            "-DREGISTER_GUI_TESTS=OFF"
            "-DBUILD_TESTS=OFF"
            "-DBUILD_GUI=OFF"
            "-DUSE_BUNDLED_TINYXML2=ON"
            "-DHAVE_RULES=ON"
            "-DUSE_BOOST=OFF"
            "-DDISABLE_DMAKE=ON"
            # cppcheck custom options
            "-DDISABLE_CLANG_TIDY=ON"
    )

    # Pass relevant CMake variables.
    # We do not pass compiler or linker flags here because we do not care how external tools that are only meant for the
    # host are built as long as THEY DO NOT SHARE DEPENDENCIES WITH THE PROJECT. The only requirement is that they must
    # be built using the configured compiler so we do not have to install multiple toolchains for a given build setup.
    # NOTE: DO NOT pass variables semicolon separated lists here. Lists cannot go into PACKAGE_COMMAND_SETUP because
    #       they would be expanded in place when passed to execute_process(). Add them directly to the
    #       execute_process() call instead.
    foreach (variable
            CMAKE_SYSTEM_NAME
            CMAKE_SYSTEM_PROCESSOR
            CMAKE_CROSSCOMPILING
            CMAKE_VERBOSE_MAKEFILE
            CMAKE_COLOR_DIAGNOSTICS
            CMAKE_MESSAGE_INDENT
            CMAKE_C_COMPILER
            CMAKE_CXX_COMPILER
            CMAKE_FIND_ROOT_PATH_MODE_PROGRAM
            CMAKE_FIND_ROOT_PATH_MODE_INCLUDE
            CMAKE_FIND_ROOT_PATH_MODE_LIBRARY
            CMAKE_FIND_ROOT_PATH_MODE_PACKAGE
    )
        if (DEFINED ${variable})
            cmake_print_variables(${variable})
            list(APPEND PACKAGE_COMMAND_SETUP "-D${variable}=${${variable}}")
        endif ()
    endforeach ()

    # Run package setup
    file(MAKE_DIRECTORY "${PACKAGE_BUILD_DIR}")
    execute_process(
            COMMAND ${PACKAGE_COMMAND_SETUP}
            # Pass the paths to our staged dependencies (if any).
            # These cannot go into PACKAGE_COMMAND_SETUP because paths may be semicolon separated lists that would be
            # unintentionally expanded in place.
            "-DCMAKE_INCLUDE_PATH=${CMAKE_INCLUDE_PATH}"
            "-DCMAKE_LIBRARY_PATH=${CMAKE_LIBRARY_PATH}"
            "-DCMAKE_PROGRAM_PATH=${CMAKE_PROGRAM_PATH}"
            "-DCMAKE_FIND_ROOT_PATH=${CMAKE_FIND_ROOT_PATH}"
            WORKING_DIRECTORY "${PACKAGE_BUILD_DIR}"
            COMMAND_ERROR_IS_FATAL ANY
    )

    # NOTE: There is a known issue with Ninja prior to 1.12.0 where the output is not flushed automatically after `\n`
    #       on Windows. This may lead to line fragments appearing in the console output and ultimately may lead to
    #       output from the console pool in Ninja to be printed BEFORE the output of other jobs even when those jobs are
    #       already finished (e.g. misplaced output of an installation target appearing before the output of a build job
    #       dependency). DO NOT try to fix this by issuing separate CMake commands. The problem should go away once we
    #       can update to Ninja 1.12.x.
    #       See https://github.com/ninja-build/ninja/pull/2143

    # Run package build and install
    execute_process(
            COMMAND "${CMAKE_COMMAND}"
            --build "${PACKAGE_BUILD_DIR}"
            --config "${PACKAGE_BUILD_TYPE}"
            --target install
            WORKING_DIRECTORY "${PACKAGE_BUILD_DIR}"
            COMMAND_ERROR_IS_FATAL ANY
    )

    list(POP_BACK CMAKE_MESSAGE_INDENT)
endforeach ()
unset(PACKAGE_BUILD_SUFFIX)
