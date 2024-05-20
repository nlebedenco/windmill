include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

include(Windmill/Functions)

# C compiler features
set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# CXX compiler features
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Replace extensions in output files instead of appending (e.g. file.c becomes file.o instead of file.c.o and file.rc
# becomes file.res instead of file.rc.res)
foreach (lang IN LISTS C CXX ASM RC)
    set(CMAKE_${lang}_OUTPUT_EXTENSION_REPLACE ON)
endforeach ()

# Hide symbols by default.
# See https://gcc.gnu.org/wiki/Visibility
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)

# Check compiler is supported.
if (NOT "${CMAKE_C_COMPILER_ID}" MATCHES "^(GNU|Clang|AppleClang)$")
    message(WARNING "Unsupported compiler: ${CMAKE_C_COMPILER_ID}")
endif ()

# Check absolute minimum versions required for known compilers
windmill_compiler_minimum_version("GNU" 12.0)
windmill_compiler_minimum_version("Clang" 17.0)
windmill_compiler_minimum_version("AppleClang" 15.0)

if (CMAKE_TOOLCHAIN_FILE)
    foreach (lang IN ITEMS C CXX)
        # Check compiler expected by toolchain if defined
        if (DEFINED WINDMILL_TOOLCHAIN_COMPILER_ID)
            if (NOT "${CMAKE_${lang}_COMPILER_ID}" STREQUAL "${WINDMILL_TOOLCHAIN_COMPILER_ID}")
                message(FATAL_ERROR "Invalid compiler"
                        " (Required is \"${WINDMILL_TOOLCHAIN_COMPILER_ID}\")\n"
                        "    Reason given by configuration:\n"
                        "        Compiler: Wrong id for the compiler \"${CMAKE_${lang}_COMPILER}\""
                )
            endif ()
        else ()
            message(STATUS "Could NOT verify toolchain ${lang} compiler (missing WINDMILL_TOOLCHAIN_COMPILER_ID)")
        endif ()

        # Check compiler frontend expected by toolchain if defined
        if (DEFINED WINDMILL_TOOLCHAIN_COMPILER_FRONTEND_VARIANT)
            if (NOT "${CMAKE_${lang}_COMPILER_FRONTEND_VARIANT}" STREQUAL "${WINDMILL_TOOLCHAIN_COMPILER_FRONTEND_VARIANT}")
                message(FATAL_ERROR "Invalid compiler frontend variant"
                        " (Required is \"${WINDMILL_TOOLCHAIN_COMPILER_FRONTEND_VARIANT}-like command line\")\n"
                        "    Reason given by configuration:\n"
                        "        Compiler: Wrong frontend variant for the compiler \"${CMAKE_${lang}_COMPILER}\""
                )
            endif ()
        else ()
            message(STATUS "Could NOT verify toolchain ${lang} compiler (missing WINDMILL_TOOLCHAIN_COMPILER_FRONTEND_VARIANT)")
        endif ()

        # Check compiler version expected by toolchain if defined
        if (DEFINED WINDMILL_TOOLCHAIN_COMPILER_MINIMUM_VERSION)
            if (NOT "${CMAKE_${lang}_COMPILER_VERSION}" VERSION_GREATER_EQUAL "${WINDMILL_TOOLCHAIN_COMPILER_MINIMUM_VERSION}")
                message(FATAL_ERROR "Invalid compiler version"
                        " (Required is at least version \"${WINDMILL_TOOLCHAIN_COMPILER_MINIMUM_VERSION}\")\n"
                        "    Reason given by configuration:\n"
                        "        Compiler: Wrong version for the compiler \"${CMAKE_${lang}_COMPILER}\""
                )
            endif ()
        else ()
            message(STATUS "Could NOT verify toolchain ${lang} compiler version (missing WINDMILL_TOOLCHAIN_COMPILER_MINIMUM_VERSION)")
        endif ()
    endforeach ()
endif ()

# Disable permissive mode in MSVC (including clang-cl) when compiler extensions are disabled.
# This cannot go into Windmill/Compilers/MSVC because it applies to any other compiler simulating MSVC as well.
if (MSVC)
    foreach (lang IN ITEMS C CXX)
        add_compile_options("$<$<AND:$<COMPILE_LANGUAGE:${lang}>,$<NOT:$<BOOL:$<TARGET_PROPERTY:${lang}_EXTENSIONS>>>>:/permissive->")
    endforeach ()
endif ()
