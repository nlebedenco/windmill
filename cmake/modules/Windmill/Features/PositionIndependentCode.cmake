include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

include(CMakeDependentOption)
include(CheckPIESupported)
include(CheckCCompilerFlag)
include(CheckCXXCompilerFlag)

# Enable Position independent code binaries if supported.
check_pie_supported()

# If the target is a library, the flag -fPIC is added by CMake to the compilation and linker steps.
# If the target is an executable, the flag -fPIE is added by CMake to the compilation and linker steps.
# Microsoft Windows DLLs are not shared libraries in the Unix sense and do not use position independent code.
# See http://en.wikipedia.org/wiki/Position-independent_code
cmake_dependent_option(CMAKE_POSITION_INDEPENDENT_CODE "" ON
        "CMAKE_C_LINK_PIE_SUPPORTED AND NOT CMAKE_SYSTEM_NAME STREQUAL \"Zephyr\"" OFF)

# Semantic interposition can be disabled to improve performance of PIC code.
# See https://maskray.me/blog/2021-05-09-fno-semantic-interposition
#
# DO NOT pass -Bsymbolic-functions here because:
#
#     1) we already compile with -fvisibility=hidden via CMAKE_<LANG>_VISIBILITY_PRESET;
#     2) it will apply to third-party static libraries (because static libs are not pre-linked);
#     3) third-party shared libraries might have their own strategy for symbol visibility (e.g. export all and only hide
#        specific ones)
#
# Also mind that LD_PRELOAD is ignored for symbols compiled with hidden visibility AND libraries linked with
# -Bsymbolic-functions.
# See https://labjack.com/blogs/news/simple-c-symbol-visibility-demo
#
# NOTE: Semantic interposition is what allows replacing symbols (functions/variables) in runtime with those from another
#       pre-loaded library. This is usually accomplished with the help of environment variables such as LD_PRELOAD
#       (on Linux) or DYLD_INSERT_LIBRARIES (on Darwin/macOS). Many custom memory allocator libraries such as jemalloc
#       and mimalloc rely on this mechanism to replace malloc/free calls of a process without the need for the original
#       executable to have been linked to those libraries.
if (CMAKE_POSITION_INDEPENDENT_CODE)
    foreach (lang IN ITEMS C CXX)
        if ("${CMAKE_${lang}_COMPILER_ID}" MATCHES "^(GNU|Clang|AppleClang)$")
            string(TOLOWER "check_${lang}_compiler_flag" check)
            set(switch)
            if (NOT WINDMILL_ENABLE_SEMANTIC_INTERPOSITION)
                set(switch no-)
            endif ()
            cmake_language(CALL "${check}" "-f${switch}semantic-interposition" ${lang}_HAS_NO_SEMANTIC_INTERPOSITION)
            unset(check)
            unset(switch)
            if (${lang}_HAS_NO_SEMANTIC_INTERPOSITION)
                add_compile_options($<$<COMPILE_LANGUAGE:${lang}>:-fno-semantic-interposition>)
            endif ()
        endif ()
    endforeach ()
endif ()
