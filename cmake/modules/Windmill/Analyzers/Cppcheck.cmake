include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

include(CheckTypeSize)

if (WINDMILL_ENABLE_CPPCHECK)
    set(WINDMILL_CPPCHECK_DIR "${WINDMILL_SOURCE_DIR}/extras/cppcheck")
    set(WINDMILL_CPPCHECK_SUPRESSIONS_FILE "${WINDMILL_CPPCHECK_DIR}/supressions.txt")
    set(WINDMILL_CPPCHECK_RULES_FILE "${WINDMILL_CPPCHECK_DIR}/rules.xml")

    # Analyzers should be required because the user can explicitly disable it using command line options.
    # Using find_package here instead of find_program to invoke our custom find module which can automatically check
    # the minimum version specified in the package declaration (if any).
    find_package(Cppcheck REQUIRED)

    set(command "${Cppcheck_EXECUTABLE}")
    if (WINDMILL_CPPCHECK_CHECKS)
        list(APPEND command "--enable=${WINDMILL_CPPCHECK_CHECKS}")
    endif ()
    if (WINDMILL_CPPCHECK_WARNING_AS_ERROR)
        # With cppcheck the exit code is evaluated. An exit code of 0 means success. Other than 0, failure. All you have
        # to do is to configure cppcheck with --error-exitcode. We use '2' because '1' is returned if arguments are not
        # valid or if no input files are provided.
        list(APPEND command --error-exitcode=2)
    endif ()
    list(APPEND command
            --inline-suppr
            "--suppressions-list=${WINDMILL_CPPCHECK_SUPRESSIONS_FILE}"
            "--rule-file=${WINDMILL_CPPCHECK_RULES_FILE}"
    )
    foreach (include IN LISTS CMAKE_C_STANDARD_INCLUDE_DIRECTORIES)
        list(APPEND command "-I${include}")
    endforeach ()
    if (CMAKE_VERBOSE_MAKEFILE)
        list(APPEND command --verbose)
    else ()
        list(APPEND command --quiet)
    endif ()
    if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Zephyr")
        list(APPEND command --library=zephyr)
        if (CONFIG_ARCH)
            if ("${CONFIG_ARCH}" STREQUAL "arm")
                check_type_size(wchar_t SIZE_OF_WCHAR_T)
                list(APPEND command
                        --platform=arm32-wchar_t${SIZE_OF_WCHAR_T}
                )
            elseif ("${CONFIG_ARCH}" STREQUAL "arm64")
                check_type_size(wchar_t SIZE_OF_WCHAR_T)
                list(APPEND command
                        --platform=arm64-wchar_t${SIZE_OF_WCHAR_T}
                )
            elseif ("${CONFIG_ARCH}" STREQUAL "mips")
                list(APPEND command
                        --platform=mips32
                )
            elseif ("${CONFIG_ARCH}" STREQUAL "posix")
                list(APPEND command
                        --library=posix
                        --platform=native
                )
            else ()
                list(APPEND command
                        "--platform=${WINDMILL_CPPCHECK_DIR}/platforms/${CONFIG_ARCH}.xml"
                )
            endif ()
        endif ()
    elseif ("${CMAKE_SYSTEM_NAME}" STREQUAL "Windows")
        list(APPEND command
                --library=windows
                --platform=win64
        )
    elseif ("${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
        list(APPEND command
                --library=posix
                --library=gnu
        )
        if (CMAKE_SIZEOF_VOID_P EQUAL 8)
            list(APPEND command --platform=unix64)
        else ()
            list(APPEND command --platform=unix32)
        endif ()
    elseif ("${CMAKE_SYSTEM_NAME}" STREQUAL "Darwin")
        list(APPEND command
                --library=posix
                --platform=unix64
        )
    else ()
        list(APPEND command --platform=native)
    endif ()
    # Adjustments for GCC compatibility
    if ("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU")
        # TODO: Add typical GNUC predefined macros such as
        #       __GNUC__
        #       __GNUC_MINOR__
        #       __GNUC_PATCHLEVEL__
        # TODO: Do we also need these macros?
        #       __SIZEOF_INT__
        #       __SIZEOF_LONG__
        #       __SIZEOF_LONG_LONG__
        #       __SIZEOF_SHORT__
        #       __SIZEOF_POINTER__
        #       __SIZEOF_FLOAT__
        #       __SIZEOF_DOUBLE__
        #       __SIZEOF_LONG_DOUBLE__
        #       __SIZEOF_SIZE_T__
        #       __SIZEOF_WCHAR_T__
        #       __SIZEOF_WINT_T__
        #       __SIZEOF_PTRDIFF_T__
        #       __BYTE_ORDER__
        #       __ORDER_LITTLE_ENDIAN__
        #       __ORDER_BIG_ENDIAN__
        #       __ORDER_PDP_ENDIAN__
    endif ()
    foreach (lang IN ITEMS C CXX)
        if (NOT CMAKE_${lang}_CPPCHECK)
            set(CMAKE_${lang}_CPPCHECK "${command}")
        endif ()
    endforeach ()
    unset(command)
endif ()
