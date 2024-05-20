include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

include(Windmill/Systems/Common)

# Target system ABI.
# We only really support the GNU ABI for Linux.
set(WINDMILL_SYSTEM_ABI "GNU")

# Target system ABI version
# HACK: Glibc offers backward compatibility but it is not possible to compile and link a binary with a recent version
#       and yet restrict the linker to symbols of an arbitrary older version. GCC does not support anything similar to
#       the -mmacosx-version-min flag available in AppleClang. The only way to guarantee compatibility between project
#       binaries and pre-compiled packages is to build with the glibc you target (i.e. an old glibc).
#       Of course, backward compatibility in glibc is not absoulte, but a resonable aproximation (some symbols are in
#       fact removed from time to time).
#       See https://developers.redhat.com/blog/2019/08/01/how-the-gnu-c-library-handles-backward-compatibility
#       See https://abi-laboratory.pro/?view=timeline&l=glibc
#
# NOTE: The include header <features.h> does not exist on all platforms, so it cannot be included without further ado.
#       However, since it is included by other GNU glibc header files, a better way to obtain the glibc macros is to
#       include the <limits.h> header file (see e.g. paragraph 4/6 in ISO/IEC 9899:1999).
if (NOT DEFINED GLIBC_VERSION)
    execute_process(
            COMMAND "${CMAKE_COMMAND}" -E echo "__GLIBC__ __GLIBC_MINOR__"
            COMMAND "${CMAKE_C_COMPILER}" -include limits.h -E -P -
            OUTPUT_VARIABLE version
            COMMAND_ERROR_IS_FATAL ANY
    )
    string(STRIP "${version}" version)
    if ("${version}" MATCHES "^([0-9]+) ([0-9]+)$")
        string(REGEX REPLACE "^([0-9]+) ([0-9]+)$" "\\1.\\2" version "${version}")
    else ()
        set(version "")
    endif ()
    set(GLIBC_VERSION "${version}" CACHE STRING "")
    mark_as_advanced(GLIBC_VERSION)
    unset(version)
endif ()
set(WINDMILL_SYSTEM_ABI_VERSION "${GLIBC_VERSION}")

# Target system platform.
# Linux systems on Intel 32/64 are "PC"; anything else is "Unknown".
if ("${CMAKE_SYSTEM_PROCESSOR}" MATCHES "^([Aa][Mm][Dd]64|[Xx]86_64|[Xx]64|[Xx]86)$")
    set(WINDMILL_SYSTEM_PLATFORM "PC")
else ()
    set(WINDMILL_SYSTEM_PLATFORM "Unknown")
endif ()

# Check minimum Linux kernel version.
if (NOT "${CMAKE_SYSTEM_VERSION}" VERSION_GREATER_EQUAL "${WINDMILL_LINUX_MINIMUM_VERSION}")
    message(FATAL_ERROR "Invalid target system version: \"${CMAKE_SYSTEM_VERSION}\""
            " (expected >= \"${WINDMILL_LINUX_MINIMUM_VERSION}\"")
endif ()

# Compiler options common to all build targets
# Enable lightweight checks on Linux to detect some buffer overflow errors when employing various string and memory
# manipulation functions (for example, memcpy(3), memset(3), stpcpy(3), strcpy(3), strncpy(3), strcat(3), strncat(3),
# sprintf(3), snprintf(3), vsprintf(3), vsnprintf(3), gets(3), and wide character variants thereof). Some gcc distros
# predefine _FORTIFY_SOURCE so a simple add_compile_definition() could fail which is why we make sure to first undefine
# it using add_compile_options().
#     - _FORTIFY_SOURCE=1 adds checks at compile-time only (some headers are necessary as #include <string.h>)
#     - _FORTIFY_SOURCE=2 also adds checks at run-time (detected buffer overflow terminates the program)
# See https://stackoverflow.com/a/16604146

# NOTE: _FORTIFY_SOURCE should be undefined when sanitizers are used.
#       See https://developers.redhat.com/blog/2021/05/05/memory-error-checking-in-c-and-c-comparing-sanitizers-and-valgrind
add_compile_options("$<$<COMPILE_LANGUAGE:C,CXX>:-U_FORTIFY_SOURCE;-D_FORTIFY_SOURCE=2>")

# Compiler directives common to all build targets
add_compile_definitions(
        # GLibc features: Enable C11 API compatibility
        # See https://linux.die.net/man/7/feature_test_macros
        _ISOC11_SOURCE=1
)

# Indicate that we are building in Microsoft WSL. This is useful to handle incompatibilities
# and limitations of WSL, specially in tests.
if (WSL)
    add_compile_definitions(__wsl__=1)
endif ()

# Link options common to all build targets
add_link_options()
