# On Windows, LLVM must be compiled with MSVC or Clang-CL, a pure Clang compiler is not supported.
if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Windows"
        AND NOT "${CMAKE_C_COMPILER_ID}" STREQUAL "MSVC"
        AND NOT "${CMAKE_C_SIMULATE_ID}" STREQUAL "MSVC")
    message(WARNING " Incompatible compiler: ${CMAKE_C_COMPILER_ID}. "
            " Package ${PACKAGE_NAME} can only be compiled for Windows with MSVC"
            " or a compiler that simulates MSVC (e.g. clang-cl).")
    return()
endif ()

# IWYU is built as part of the LLVM project build
cmake_path(SET PACKAGE_LLVM_SOURCE_DIR NORMALIZE "${PACKAGE_SOURCE_DIR}/../llvm-project/llvm")

# List of build types to generate
set(PACKAGE_BUILD_TYPES Release)

# Clean build folders
file(REMOVE_RECURSE
        "${PACKAGE_BINARY_DIR}"
        "${PACKAGE_OUTPUT_DIR}"
)

foreach (PACKAGE_BUILD_TYPE IN LISTS PACKAGE_BUILD_TYPES)
    message(CHECK_START "Building ${PACKAGE_NAME} for ${WINDMILL_SYSTEM_TRIPLET} (${PACKAGE_BUILD_TYPE})")
    list(APPEND CMAKE_MESSAGE_INDENT "    ")

    # Build directory passed to setup and build commands
    cmake_path(SET PACKAGE_BUILD_DIR NORMALIZE "${PACKAGE_BINARY_DIR}/${PACKAGE_BUILD_TYPE}")

    # The release build is the default.
    # Artifacts from other build types must be placed in <PACKAGE_INSTALL_DIR>/opt/<PACKAGE_BUILD_TYPE>.
    set(PACKAGE_INSTALL_DIR "${PACKAGE_OUTPUT_DIR}")
    if (NOT PACKAGE_BUILD_TYPE STREQUAL "Release")
        cmake_path(APPEND PACKAGE_INSTALL_DIR "opt" "${PACKAGE_BUILD_TYPE}")
    endif ()

    # Define package configuration variables
    set(PACKAGE_COMMAND_SETUP
            "${CMAKE_COMMAND}"
            -G "${PACKAGE_GENERATOR}"
            -S "${PACKAGE_LLVM_SOURCE_DIR}"
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
            # LLVM options
            # It's more convenient to use LLVM_TARGETS_TO_BUILD=host since we're only ever going to build for the host
            # system rather than trying to match our target system with LLVM targets.
            "-DLLVM_TARGETS_TO_BUILD=host"
            "-DLLVM_ENABLE_PROJECTS=clang"
            "-DLLVM_EXTERNAL_PROJECTS=iwyu"
            "-DLLVM_EXTERNAL_IWYU_SOURCE_DIR=${PACKAGE_SOURCE_DIR}"
            "-DLLVM_ENABLE_WARNINGS=OFF"
            "-DLLVM_INCLUDE_BENCHMARKS=OFF"
            "-DLLVM_INCLUDE_TESTS=OFF"
            "-DLLVM_INCLUDE_EXAMPLES=OFF"
            "-DLLVM_ENABLE_ZLIB=OFF"
            "-DLLVM_ENABLE_LIBXML2=OFF"
            "-DLLVM_ENABLE_LIBEDIT=OFF"
            "-DLLVM_ENABLE_BINDINGS=OFF"
    )

    # Pass relevant CMake variables.
    # We do not pass compiler or linker flags here because we do not care how external tools that are only meant for the
    # host are built as long as THEY DO NOT SHARE DEPENDENCIES WITH THE PROJECT. The only requirement is that they must
    # be built using the configured compiler so we do not have to install multiple toolchains for a given build setup.
    foreach (variable
            CMAKE_SYSTEM_NAME
            CMAKE_SYSTEM_PROCESSOR
            CMAKE_CROSSCOMPILING
            CMAKE_VERBOSE_MAKEFILE
            CMAKE_COLOR_DIAGNOSTICS
            CMAKE_MESSAGE_INDENT
            CMAKE_C_COMPILER
            CMAKE_CXX_COMPILER
    )
        if (DEFINED ${variable})
            cmake_print_variables(${variable})
            list(APPEND PACKAGE_CACHE_ARGS "-D${variable}=${${variable}}")
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

    # Run package build and install
    # FIXME: There is a known issue with Ninja prior to 1.12.0 where the output is not flushed automatically after `\n`
    #        on Windows. This may lead to line fragments appearing in the console output and ultimately may lead to
    #        output from the console pool in Ninja to be printed BEFORE the output of other jobs even when those jobs
    #        seem to have finished (e.g. misplaced output of an installation target appearing before the output of a
    #        build job dependency). DO NOT try to fix this by issuing separate CMake commands. The problem should go
    #        away once we can update to Ninja 1.12.x.
    #        See https://github.com/ninja-build/ninja/pull/2143
    execute_process(
            COMMAND "${CMAKE_COMMAND}"
            --build "${PACKAGE_BUILD_DIR}"
            --config "${PACKAGE_BUILD_TYPE}"
            --target install-clang-resource-headers tools/iwyu/install
            WORKING_DIRECTORY "${PACKAGE_BUILD_DIR}"
            COMMAND_ERROR_IS_FATAL ANY
    )

    # Remove unecessary files and directories
    file(REMOVE_RECURSE
            "${PACKAGE_INSTALL_DIR}/share/man"
    )

    list(POP_BACK CMAKE_MESSAGE_INDENT)
endforeach ()
