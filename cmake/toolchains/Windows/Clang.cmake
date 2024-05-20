include_guard()

########################################################################################################################
# Definitions
########################################################################################################################
# Expected compiler id
set(WINDMILL_TOOLCHAIN_COMPILER_ID "Clang")

# Expected compiler frontend variant
set(WINDMILL_TOOLCHAIN_COMPILER_FRONTEND_VARIANT "MSVC")

# Minimum compiler version required.
# Clang has partial C17 and full C++17 support since version 15.0 and minimum C++20 support since version 16.0.
# Visual Studio 2022 17.9 ships with Clang 17.0.3
# See https://en.wikipedia.org/wiki/Microsoft_Visual_C#Internal_version_numbering
set(WINDMILL_TOOLCHAIN_COMPILER_MINIMUM_VERSION 17.0)

########################################################################################################################
# Options
########################################################################################################################
# Minimum target system version required (corresponds to the Windows SDK version).
# MSVC requires Windows SDK >= 10.0.20348.0 for C11 compatibility
# See https://docs.microsoft.com/en-us/cpp/overview/visual-cpp-language-conformance?view=msvc-170
set(WINDMILL_WINDOWS_MINIMUM_VERSION 10.0.20348.0 CACHE STRING "")

# Value assigned to compile time constants WINVER and _WIN32_WINNT to define the Windows API compatibility level.
# For MinGW, we need to specify _WIN32_WINNT to at least 0x0600 ("NT 6.0", aka Vista/Windows Server 2008)
# in order to have full IPv6 support, including in inet_ntop(), and we need to specify it as 0x0601 ("NT 6.1", aka
# Windows 7) to have NdisMediumIP. Current default value is 0x0A00 for Windows 10.
# See https://learn.microsoft.com/en-us/windows/win32/winprog/using-the-windows-headers
set(WINDMILL_WINDOWS_WINVER 0x0A00 CACHE STRING "")

# Symbol assigned to the compile-time constant NTDDI_VERSION. Used to verify the SDK selected by the compiler supports
# the minimum version required. The value must be a NTDDI constant name defined in <sdksdver.h>.
# See https://learn.microsoft.com/en-us/windows/win32/winprog/using-the-windows-headers
set(WINDMILL_WINDOWS_NTDDI_SYMBOL NTDDI_WIN10_FE CACHE STRING "")

########################################################################################################################
# Configuration
########################################################################################################################
# Default target system name
set(CMAKE_SYSTEM_NAME "Windows" CACHE STRING "")

# Default target system processor
set(processor "AMD64")
if ("${CMAKE_SYSTEM_NAME}" STREQUAL "${CMAKE_HOST_SYSTEM_NAME}")
    set(processor "${CMAKE_HOST_SYSTEM_PROCESSOR}")
endif ()
set(CMAKE_SYSTEM_PROCESSOR "${processor}" CACHE STRING "")
unset(processor)

# Default target system version.
# This is only a hint for generators and is double-checked after the first call to project(). Notably even the
# VS generator will fallback to the latest SDK if a suitable one cannot be found.
# See https://cmake.org/cmake/help/latest/variable/CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION.html
# See https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling-for-windows-10-universal-applications
# See https://gitlab.kitware.com/cmake/cmake/-/issues/20773
# See https://gitlab.kitware.com/cmake/cmake/-/issues/16713
set(version "${WINDMILL_WINDOWS_MINIMUM_VERSION}")
if ("${CMAKE_SYSTEM_NAME}" STREQUAL "${CMAKE_HOST_SYSTEM_NAME}"
        AND "${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "${CMAKE_HOST_SYSTEM_PROCESSOR}")
    set(version "${CMAKE_HOST_SYSTEM_VERSION}")
endif ()
set(CMAKE_SYSTEM_VERSION "${version}" CACHE STRING "")
unset(version)

# Validate target system name.
if (NOT "${CMAKE_SYSTEM_NAME}" STREQUAL "Windows")
    message(FATAL_ERROR "Toolchain file does not support the target system: \"${CMAKE_SYSTEM_NAME}\"")
endif ()

# Fix the cross-compilation indicator. We only consider cross-compiling to be to a different system name or different
# processor except when the host is x86_64 and we are targeting x86 because AMD 64-bit systems support 32-bit binaries.
#
# NOTE: CMake always sets CMAKE_CROSSCOMPILING to TRUE when CMAKE_SYSTEM_NAME is explicitly set even if it is set to the
#       same value of CMAKE_HOST_SYSTEM_NAME.
#       See https://cmake.org/cmake/help/latest/variable/CMAKE_CROSSCOMPILING.html
#       See https://gitlab.kitware.com/cmake/cmake/-/issues/17653
#       See https://gitlab.kitware.com/cmake/cmake/-/issues/21744
if ("${CMAKE_SYSTEM_NAME}" STREQUAL "${CMAKE_HOST_SYSTEM_NAME}"
        AND ("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "${CMAKE_HOST_SYSTEM_PROCESSOR}"
        OR "${CMAKE_HOST_SYSTEM_PROCESSOR}->${CMAKE_SYSTEM_PROCESSOR}" MATCHES "^([Aa][Mm][Dd]64|[Xx]86_64|[Xx]64)->[Xx]86$"))
    set(CMAKE_CROSSCOMPILING OFF CACHE BOOL "" FORCE)
endif ()

# All modules passed to a given invocation of the linker must have been compiled with the same run-time library
# (/MD, /MT or /LD) but we don't track whether a pre-compiled package was built with a dynamic or static CRT. All are
# presumed to be compiled with a matching one (/MD or /MDd). Even if we did track it in the target triplet, we would
# also have to pin down which static CRT was used in each build because static CRTs are not necessarily compatible and
# mixing them may cause all sorts of runtime errors. In other words, static CRTs affect the ABI.
# See https://learn.microsoft.com/en-us/cpp/c-runtime-library/crt-library-features?view=msvc-170
# See https://stackoverflow.com/a/57478728
# See https://developer.apple.com/library/archive/qa/qa1118/_index.html
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL" CACHE STRING "" FORCE)

# Compile with -Z7 or equivalent flag(s) to produce object files with full symbolic debugging information.
# By default, if no debug information format option is specified (no /Z option), the compiler produces no debugging
# information, so compilation is faster. We use old C7 format (/Z7) to store debug symbols in obj files directly instead
# of separate PDB files (/Zi). This is analogous to -gsplit-dwarf=single in gcc/clang and it is often required by
# compiler caching solutions (i.e. ccache) to work. Otherwise cached object files would be paired with the wrong PDBs.
# This also means static libraries will carry debug symbols but final binaries (DLLs and EXEs) are still striped by the
# linker which will then produce a separate PDB. This is independently controlled by the /DEBUG option passed to the
# linker.
#
# See https://github.com/mbitsnbites/buildcache/blob/master/doc/usage.md
# See https://github.com/microsoft/vcpkg/issues/9084
# See https://cmake.org/cmake/help/latest/variable/CMAKE_MSVC_DEBUG_INFORMATION_FORMAT.html
#
# NOTE: clang-cl /Zi is an alias for /Z7 and does not produce any PDBs.
#       See https://clang.llvm.org/docs/UsersManual.html#clang-cl
set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "$<$<CONFIG:Debug,RelWithDebInfo>:Embedded>" CACHE STRING "" FORCE)

# Compiler executables.
# CMake accepts compiler variables with a relative path.
# See https://gitlab.kitware.com/cmake/cmake/-/issues/18087
#
# If the host system contains multiple VS installations and the build is not configured with a Visual Studio generator
# then the user is resposible to ensure that CMake is invoked inside a developer command prompt using the correct
# environment variables (i.e. vcvars) or pass CMAKE_C_COMPILER manually pointing to a valid clang-cl executable.
set(CMAKE_C_COMPILER clang-cl CACHE PATH "")
set(CMAKE_CXX_COMPILER clang-cl CACHE PATH "")

# Default compiler and linker flags
set(CMAKE_USER_MAKE_RULES_OVERRIDE "${CMAKE_CURRENT_LIST_DIR}/Rules/Clang.cmake")
