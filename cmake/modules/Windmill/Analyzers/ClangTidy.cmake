include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

# Minimum version required for the clang-tidy verify command. This is defined because we may have checks in our
# .clang-tidy that are only supported in clang versions greater than the minimum required to build the project.
# Unsupported checks are simply ignored by clang-tidy but running a strict config verification would fail.
set(WINDMILL_CLANG_TIDY_VERIFY_CONFIG_MINIMUM_VERSION 17.0 CACHE STRING "")

if (WINDMILL_ENABLE_CLANG_TIDY)
    set(WINDMILL_CLANG_TIDY_WRAPPER "${WINDMILL_SOURCE_DIR}/extras/python/linter.py")
    set(WINDMILL_CLANG_TIDY_WRAPPER_CONFIG_FILE "${WINDMILL_SOURCE_DIR}/extras/clang-tidy/clang-tidy.yml")

    # Analyzers should be marked as required because the user can explicitly disable it using command line options.
    # Using find_package here instead of find_program to invoke our custom find module which can automatically check
    # the minimum version specified in the package declaration (if any).
    find_package(ClangTidy REQUIRED)

    # Validate .clang-tidy if possible.
    if ("${ClangTidy_VERSION}" VERSION_GREATER_EQUAL "${WINDMILL_CLANG_TIDY_VERIFY_CONFIG_MINIMUM_VERSION}")
        execute_process(
                COMMAND "${ClangTidy_EXECUTABLE}" --verify-config
                OUTPUT_QUIET
                COMMAND_ERROR_IS_FATAL ANY
        )
    else ()
        message(STATUS "Could NOT verify clang-tidy configuration file"
                " (found version \"${ClangTidy_VERSION}\", but minimum required is \"${WINDMILL_CLANG_TIDY_VERIFY_CONFIG_MINIMUM_VERSION}\")")
    endif ()

    set(command "${Python3_EXECUTABLE}" -u "${WINDMILL_CLANG_TIDY_WRAPPER}")
    if (EXISTS "${WINDMILL_CLANG_TIDY_WRAPPER_CONFIG_FILE}")
        list(APPEND command "--config-file=${WINDMILL_CLANG_TIDY_WRAPPER_CONFIG_FILE}")
    else ()
        message(AUTHOR_WARNING "Could NOT find WINDMILL_CLANG_TIDY_WRAPPER_CONFIG_FILE"
                " using file: \"${WINDMILL_CLANG_TIDY_WRAPPER_CONFIG_FILE}\")")
    endif ()
    list(APPEND command
            "${ClangTidy_EXECUTABLE}"
            --
    )

    # Warnings as errors.
    # The option `--warnings-as-errors=<string>` upgrades warnings to errors. Same format as '-checks'. This option's
    # value is APPENDED to the value of the 'WarningsAsErrors' option in the .clang-tidy file, if any. We have to
    # assume the configuration file has warnings as errors enabled by default for all warnings and disabled for eventual
    # exceptions so if we disable all with a command-line override it will not contradict the exceptions. Note that the
    # opposite does not work so well. If the file had warnings disabled by default (with a few exceptions enabled),
    # trying to disable all would be in contradiction to the exceptions defined in the config file which violates the
    # principle of least astonishment.
    if (NOT WINDMILL_CLANG_TIDY_WARNING_AS_ERROR)
        list(APPEND command "--warnings-as-errors=-*")
    endif ()

    # Header filter.
    string(REGEX REPLACE "([][+.*()^])" "\\\\\\1" regex "${WINDMILL_SOURCE_DIR}")
    string(REGEX REPLACE "[\\/]" "[\\\\\\\\/]" regex "${regex}")
    list(APPEND command
            # Analyze headers only from the source folder. This cannot be defined in .clang-tidy using
            # HeaderFilterRegex because we need to know the full path of the project. Matching to a relative path
            # is prone to issues because the base folder names are general enough that could also appear in the root
            # path producing unintended matches."
            --header-filter "^${regex}[\\\\/](embedded|general)[\\\\/].*$"
    )
    unset(regex)

    # Adjustments for GCC compatibility
    #
    # NOTE: There is no use in trying to pass -fgnuc-version=${CMAKE_C_COMPILER_VERSION}" because Clang has only
    #       partial support to GNU extensions and lack many recent ones. For example, GCC 11 introduced three
    #       forms of the __malloc__ attribute:
    #
    #           - __malloc__
    #           - __malloc__(deallocator)
    #           - __malloc__(deallocator, ptr-index)
    #
    #       But Clang 17 (and earlier) only supports the first. For better compatibility, let Clang decide which GNUC
    #       version to report.
    if ("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU")
        # The Clang backend of IWYU needs an explict target when cross compiling.
        if (CMAKE_CROSSCOMPILING)
            execute_process(
                    COMMAND "${CMAKE_C_COMPILER}" -dumpmachine
                    OUTPUT_VARIABLE triplet
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    COMMAND_ERROR_IS_FATAL ANY
            )
            list(APPEND command "--extra-arg-before=--target=${triplet}")
            unset(triplet)

            if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Zephyr")
                if (NOT CONFIG_PICOLIBC_USE_MODULE)
                    # Picolibc provides a spec file for use with gcc but clang does not support spec files and simply
                    # ignores the argument so we have to provide that information directly here. Zephyr SDK ships the
                    # spec file at ${SYSROOT_DIR}\lib\picolibc.specs but we cannot effectively parse it since it depends
                    # on the values of custom gcc params -picolib-prefix and -picolibc-buildtype. Besides, other
                    # toolchains might require different adjustments. For now, only the Zephyr SDK is supported for
                    # which we know the include paths to add.
                    # See https://releases.llvm.org/17.0.1/tools/clang/docs/DriverInternals.html#relation-to-gcc-driver-concepts
                    list(APPEND command
                            "--extra-arg=-isystem"
                            "--extra-arg=${TOOLCHAIN_HOME}/${SYSROOT_TARGET}/picolibc/include"
                    )
                endif ()
            endif ()
        endif ()
    endif ()


    if (NOT CMAKE_VERBOSE_MAKEFILE)
        # NOTE: clang-tidy shipped with PyPi may output a line like "Resource filename: <executable path>" to indicate
        #       that the executable invoked is a wrapper over a another one. This message is not an error but it cannot
        #       be silenced either.
        list(APPEND command --quiet)
    endif ()
    foreach (lang IN ITEMS C CXX)
        if (NOT CMAKE_${lang}_CLANG_TIDY)
            set(CMAKE_${lang}_CLANG_TIDY "${command}")
        endif ()
    endforeach ()
    unset(command)
endif ()
