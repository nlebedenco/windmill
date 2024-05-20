include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

include(Windmill/Functions)

# Determine host system platform.
# Darwin is always "Apple" and "Windows"  is always "PC". For Linux we assume a host on Intel 32/64 or ARM64 is a "PC".
# Check if variable is already defined instead of setting a cache default because CMake does not use the cache for
# CMAKE_HOST_SYSTEM_NAME and CMAKE_HOST_SYSTEM_PROCESSOR either.
if (NOT DEFINED WINDMILL_HOST_SYSTEM_PLATFORM)
    if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Darwin")
        set(WINDMILL_HOST_SYSTEM_PLATFORM "Apple")
    elseif ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows")
        set(WINDMILL_HOST_SYSTEM_PLATFORM "PC")
    elseif ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Linux"
            AND "${CMAKE_HOST_SYSTEM_PROCESSOR}" MATCHES "^([Aa][Mm][Dd]64|[Xx]86_64|[Xx]64|[Xx]86|[Ii]686|[Aa][Rr][Mm]64|[Aa][Aa][Rr][Cc][Hh]64)$")
        set(WINDMILL_HOST_SYSTEM_PLATFORM "PC")
    else ()
        # Only APPLE and PC platforms can be used as hosts this way we don't have to worry about ABI compatibility
        # between embedded systems for host tools. (e.g. eabi, gnu, gnueabi, gnueabihf, ...)
        message(FATAL_ERROR "Could NOT determine a valid host system platform for \"${CMAKE_HOST_SYSTEM_NAME}\" on \"${CMAKE_HOST_SYSTEM_PROCESSOR}\"")
    endif ()
endif ()

# Determine the host system ABI and ABI version
if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows")
    # On Windows we only support the MSVC ABI. There is no support for GNU compilers including MinGW.
    set(WINDMILL_HOST_SYSTEM_ABI "MSVC")
    # MSVC ABI compatibility depends on the versions of the toolset (MSC_VER) and redistributable runtime but binary
    # compability is only guaranteed for v140 (MSC_VER 1930) and above. All v140 redistributables are backward
    # compatible so the redistributable installed on the machine just needs be the same or higher than the version of
    # the Visual C++ toolset used to create the application. Since there is a direct correlation between MSC_VER and
    # toolset version for MSC_VER >= 1900 we can map any such redistributable version A.B so that
    # A = (MSC_VER / 100) - 5) and B = (MSC_VER % 100). The current installed version number is stored in the registry
    # at HKEY_LOCAL_MACHINE\SOFTWARE[\Wow6432Node]\Microsoft\VisualStudio\14.0\VC\Runtimes\{x86|x64|ARM}. The
    # version number is 14.0 for Visual Studio 2015, 2017, 2019, and 2022 because the latest Redistributable is binary
    # compatible with previous versions back to 2015. The key is ARM, x86, or x64 depending on the installed vcredist
    # versions for the platform. (You need to check under the Wow6432Node subkey only if you're using Regedit to view
    # the version of the installed x86 package on an x64 platform.) The version number is stored in the REG_SZ string
    # value Version and also in the set of Major, Minor, Bld, and Rbld REG_DWORD values.
    # See https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files?view=msvc-170#install-the-redistributable-packages
    if ("${CMAKE_HOST_SYSTEM_PROCESSOR}" MATCHES "^([Aa][Mm][Dd]64|[Xx]86_64|[Xx]64)$")
        set(arch x64)
    else ()
        string(TOLOWER "${CMAKE_HOST_SYSTEM_PROCESSOR}" arch)
    endif ()
    set(key HKLM/SOFTWARE/Microsoft/VisualStudio/14.0/VC/Runtimes/${arch})
    unset(arch)
    cmake_host_system_information(RESULT major QUERY WINDOWS_REGISTRY "${key}" VALUE Major VIEW HOST)
    cmake_host_system_information(RESULT minor QUERY WINDOWS_REGISTRY "${key}" VALUE Minor VIEW HOST)
    if (NOT "${major}" GREATER_EQUAL 0 OR NOT "${minor}" GREATER_EQUAL 0)
        message(FATAL_ERROR "Could NOT find Microsoft Visual C++ v14.x redistributable (registry key not found: ${key})")
    endif ()
    unset(key)
    set(WINDMILL_HOST_SYSTEM_ABI_VERSION "${major}.${minor}")
    unset(major)
    unset(minor)
elseif ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Linux")
    # For Linux we only support the GNU ABI so only x86/x86_64 and arm64 hosts are supported.
    # There is no support for musl or other libc implementations.
    # Ubuntu is the distro of reference.
    set(WINDMILL_HOST_SYSTEM_ABI "GNU")
    # Find GLIBC version
    find_program(ldd_EXECUTABLE ldd REQUIRED)
    execute_process(
            COMMAND "${ldd_EXECUTABLE}" --version
            COMMAND grep ldd
            OUTPUT_VARIABLE output
            OUTPUT_STRIP_TRAILING_WHITESPACE
            COMMAND_ERROR_IS_FATAL ANY
    )
    unset(ldd)
    if ("${output}" MATCHES "^ldd[ \t]+.*([0-9]+\\.[0-9]+)$")
        set(WINDMILL_HOST_SYSTEM_ABI_VERSION "${CMAKE_MATCH_1}")
    else ()
        message(FATAL_ERROR "Could NOT determine GLibc version of the host system (failed to parse ldd output)")
    endif ()
    unset(output)
elseif ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Darwin")
    # Darwin (macOS) only supports its won ABI (clang + libSystem) so we can use the system name and version for ABI.
    # Later, we can omit ABI in the triplet since it is going to be redundant.
    set(WINDMILL_HOST_SYSTEM_ABI "${CMAKE_HOST_SYSTEM_NAME}")
    set(WINDMILL_HOST_SYSTEM_ABI_VERSION "${CMAKE_HOST_SYSTEM_VERSION}")
else ()
    message(FATAL_ERROR "Invalid host system: \"${CMAKE_HOST_SYSTEM_NAME}\")")
endif ()
