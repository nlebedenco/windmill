include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

include(Windmill/Systems/Common)

include(CMakePushCheckState)
include(CheckSymbolExists)
include(CheckCSourceCompiles)

# Default target system ABI.
# We only really support the MSVC ABI for Windows
set(WINDMILL_SYSTEM_ABI "MSVC")

# Target system ABI version.
# HACK: Since there is a direct correlation between MSC_VER and toolset version for MSC_VER >= 1900 we can map any
#       MSC_VER to a redistributable version A.B so that A = (MSC_VER / 100) - 5) and B = (MSC_VER % 100). Note that
#       until VS 2013 the pattern was A = (MSC_VER / 100) - 6) but Microsoft broke it when it skipped VS 13.x
#       and jumped directly to 14.x with Visual Studio 2015. Now the offset is 5 instead of 6. Since Microsoft could
#       break the pattern again any time we also calculate the toolset version and compare it to the
#       MSVC_TOOLSET_VERSION found by CMake.
#       See https://en.wikipedia.org/wiki/Microsoft_Visual_C%2B%2B
math(EXPR major "(${MSVC_VERSION} / 100) - 5")
math(EXPR minor "${MSVC_VERSION} % 100")
math(EXPR toolset "(${MSVC_VERSION} / 10) - 50")
if (NOT major GREATER_EQUAL 0 OR NOT minor GREATER_EQUAL 0 OR NOT toolset EQUAL MSVC_TOOLSET_VERSION)
    message(FATAL_ERROR "Could NOT determine MSVC Toolset version (invalid MSVC_VERSION: ${MSVC_VERSION})")
endif ()
set(WINDMILL_SYSTEM_ABI_VERSION "${major}.${minor}")
unset(major)
unset(minor)
unset(toolset)

# Check that the host ABI version is greater or equal to the target ABI version. Sometimes Visual Studio publishes a
# release with a compiler version and VC runtime ahead of the latest redistributable available. There is also a chance
# that the user is trying to build in a Windows host without the necessary redistributable updates. The presumption that
# a Windows host system will always be able to run targets built for Windows is only valid if the installed
# redistributable is compatible. Unfortunately, there is no way to pass a desired VC redistributable version to CMake
# using the Ninja generator (only the Visual Studio Generator supports the CMAKE_GENERATOR_TOOLSET variable).
# See https://discourse.cmake.org/t/feature-request-give-me-a-way-to-specify-the-msvc-toolset-when-using-g-ninja/1332
# See https://cmake.org/cmake/help/v3.25/variable/CMAKE_GENERATOR_TOOLSET.html
if ("${WINDMILL_HOST_SYSTEM_ABI_VERSION}" LESS "${WINDMILL_SYSTEM_ABI_VERSION}")
    message(FATAL_ERROR "Host system ABI version (${WINDMILL_HOST_SYSTEM_ABI_VERSION})"
            " is older than one configured for the build targets (${WINDMILL_SYSTEM_ABI_VERSION})."
            " Make sure that the VC redistributable version installed in the host system is greater or equal to"
            " the VC runtime version used by the compiler")
endif ()

# Target system platform.
# Windows systems on Intel 32/64 are "PC"; anything else is "Unknown".
if ("${CMAKE_SYSTEM_PROCESSOR}" MATCHES "^([Aa][Mm][Dd]64|[Xx]86_64|[Xx]64|[Xx]86|[Aa][Rr][Mm]64|[Aa][Aa][Rr][Cc][Hh]64)$")
    set(WINDMILL_SYSTEM_PLATFORM "PC")
else ()
    set(WINDMILL_SYSTEM_PLATFORM "Unknown")
endif ()

# Check the target Windows SDK version.
# When building for windows, the target Windows SDK version is determined by CMAKE_SYSTEM_VERSION but generators are
# free to pick the latest available Windows SDK regardless so the build will not necessarily abort if there is no
# SDK available that is greater than or equal to CMAKE_SYSTEM_VERSION. The Visual Studio Generators can report the
# selected Windows SDK version so in this case we can be more precise in our check.
# See https://cmake.org/cmake/help/latest/variable/CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION.html
if (DEFINED CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION)
    if (NOT "${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION}" VERSION_GREATER_EQUAL "${WINDMILL_WINDOWS_MINIMUM_VERSION}")
        message(FATAL_ERROR "Invalid Windows SDK (expected >= \"${WINDMILL_WINDOWS_MINIMUM_VERSION}\","
                " got \"${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION}\")")
    endif ()
elseif (NOT "${CMAKE_SYSTEM_VERSION}" VERSION_GREATER_EQUAL "${WINDMILL_WINDOWS_MINIMUM_VERSION}")
    message(FATAL_ERROR "Invalid target system version: \"${CMAKE_SYSTEM_VERSION}\""
            " (expected >= \"${WINDMILL_WINDOWS_MINIMUM_VERSION}\"")
endif ()

# Check that we can specify the desired Windows API compatibility level.
set(WINDMILL_WINDOWS_WINVER_CHECKED CACHE INTERNAL "")
if (NOT WINDMILL_WINDOWS_WINVER_CHECKED OR NOT "${WINDMILL_WINDOWS_WINVER}" STREQUAL "${WINDMILL_WINDOWS_WINVER_CHECKED}")
    if (WINDMILL_WINDOWS_WINVER)
        # Check again even if the variable was already set, manually-specified or cached from a previous run
        unset(WINDMILL_WINDOWS_WINVER_SUPPORTED)
        unset(WINDMILL_WINDOWS_WINVER_SUPPORTED CACHE)
        cmake_push_check_state()
        set(CMAKE_REQUIRED_QUIET TRUE)
        set(CMAKE_REQUIRED_FLAGS "/DWINVER=${WINDMILL_WINDOWS_WINVER} /D_WIN32_WINNT=${WINDMILL_WINDOWS_WINVER}")
        check_c_source_compiles("
#include <windows.h>
int main() { return 0; }" WINDMILL_WINDOWS_WINVER_SUPPORTED)
        if (NOT WINDMILL_WINDOWS_WINVER_SUPPORTED)
            message(FATAL_ERROR "Invalid Windows SDK (unsupported WINVER \"${WINDMILL_WINDOWS_WINVER}\")")
        endif ()
        cmake_pop_check_state()
    endif ()
    set(WINDMILL_WINDOWS_WINVER_CHECKED "${WINDMILL_WINDOWS_WINVER}" INTERNAL "")
endif ()

# Check that we are using a suitable Windows SDK.
set(WINDMILL_WINDOWS_NTDDI_SYMBOL_CHECKED "" INTERNAL "")
if (NOT WINDMILL_WINDOWS_NTDDI_SYMBOL_CHECKED OR NOT "${WINDMILL_WINDOWS_NTDDI_SYMBOL}" STREQUAL "${WINDMILL_WINDOWS_NTDDI_SYMBOL_CHECKED}")
    if (WINDMILL_WINDOWS_NTDDI_SYMBOL)
        # Check again even if the variable was already set, manually-specified or cached from a previous run
        unset(WINDMILL_WINDOWS_NTDDI_SYMBOL_SUPPORTED)
        unset(WINDMILL_WINDOWS_NTDDI_SYMBOL_SUPPORTED CACHE)
        cmake_push_check_state()
        set(CMAKE_REQUIRED_QUIET TRUE)
        check_symbol_exists(${WINDMILL_WINDOWS_NTDDI_SYMBOL} "sdkddkver.h" WINDMILL_WINDOWS_NTDDI_SYMBOL_SUPPORTED)
        if (NOT WINDMILL_WINDOWS_NTDDI_SYMBOL_SUPPORTED)
            message(FATAL_ERROR "Invalid Windows SDK (NTDDI symbol not found \"${WINDMILL_WINDOWS_NTDDI_SYMBOL}\")")
        endif ()
        cmake_pop_check_state()
    endif ()
    set(WINDMILL_WINDOWS_NTDDI_SYMBOL_CHECKED "${WINDMILL_WINDOWS_NTDDI_SYMBOL}" INTERNAL "")
endif ()

# Compiler options common to all build targets
add_compile_options(
        # Enable support for utf-8 literals
        "$<$<COMPILE_LANGUAGE:C,CXX>:/utf-8>"
)

# Compiler directives common to all build targets
add_compile_definitions(
        # Windows API compatibility level
        "WINVER=${WINDMILL_WINDOWS_WINVER}"
        "_WIN32_WINNT=${WINDMILL_WINDOWS_WINVER}"
        "NTDDI_VERSION=${WINDMILL_WINDOWS_NTDDI_SYMBOL}"
        # Don't include WinAPI headers that are not explicitly required
        WIN32_LEAN_AND_MEAN
        # Default to UTF16/UCS2 WINAPI
        # UNICODE affects the character set the Windows header files treat as default. For example, GetWindowText will map
        # to GetWindowTextW instead of GetWindowTextA, for example. Similarly, the TEXT macro will map to L"..." instead of
        # "...". _UNICODE affects the character set the C runtime header files treat as default. So _tcslen will map to
        # wcslen instead of strlen, for example. Similarly, the _TEXT macro will map to L"..." instead of "...".
        # See https://devblogs.microsoft.com/oldnewthing/20040212-00/?p=40643
        UNICODE
        _UNICODE
        # Warn about deprecated functions
        _CRT_SECURE_NO_DEPRECATE
        # Suppress min/mac macros in WinDef.h
        NOMINMAX
        # Enable extended math constants. Math function are already linked in msvcrt/ucrt.
        # See https://learn.microsoft.com/en-us/cpp/c-runtime-library/math-constants?view=msvc-170
        _USE_MATH_DEFINES
)

# Link options common to all build targets
#
# NOTE: There is no use in passing /NOIMPLIB via add_link_options() to prevent executables flagged with
#       ENABLE_EXPORTS=TRUE from creating an import lib. It might appear to work at first but ENABLE_EXPORTS also
#       generates a build dependency over the import library which will cause generators (ninja, make, etc) to always
#       execute the link step even when there is nothing new to link because of the missing import library.
add_link_options()
