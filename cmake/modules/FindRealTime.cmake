# This is a special find module to get an imported target for the real time library of the target system if any
# (e.g. librt on Unix and winmm on Windows)
set(${CMAKE_FIND_PACKAGE_NAME}_FOUND FALSE)
set(target "RealTime::RealTime")
if (NOT TARGET "${target}")
    if (UNIX)
        # Check if we have to link against librt by looking for clock_gettime.
        # Specific compiler flags might affect the result of this check (e.g. glibc compiler feature macros such as
        # _XOPEN_SOURCE=600). In glibc 2.17, clock_gettime was moved from librt to libc so to be sure we find
        # clock_gettime in all systems we need to check first in libc than librt.
        #
        # Notice that the function behaviour in Linux/Android is different than in iOS (and possibly macOS).
        # To get elapsed realtime (including any time that the system is suspended) use:
        #   iOS : CLOCK_MONOTONIC
        #   Linux/Android : CLOCK_BOOTTIME
        # To get uptime (does not count time that the system is suspended) use:
        #   iOS : CLOCK_UPTIME_RAW
        #   Linux/Android : CLOCK_MONOTONIC
        if (NOT DEFINED HAVE_REALTIME)
            set(defines)
            cmake_push_check_state()
            check_symbol_exists(clock_gettime "time.h" HAVE_REALTIME)
            if (NOT HAVE_REALTIME)
                set(defines _XOPEN_SOURCE=700)
                unset(HAVE_REALTIME CACHE)
                list(TRANSFORM defines PREPEND "-D" OUTPUT_VARIABLE CMAKE_REQUIRED_DEFINITIONS)
                message(CHECK_START "Looking for clock_gettime with ${CMAKE_REQUIRED_DEFINITIONS}")
                set(CMAKE_REQUIRED_QUIET TRUE)
                check_symbol_exists(clock_gettime "time.h" HAVE_REALTIME)
                if (HAVE_REALTIME)
                    set(REALTIME_REQUIRED_DEFINITIONS "${defines}" CACHE INTERNAL "")
                    message(CHECK_PASS found)
                else ()
                    set(defines)
                    message(CHECK_PASS not found)
                endif ()
            endif ()
            cmake_pop_check_state()
            if (NOT HAVE_REALTIME)
                cmake_push_check_state()
                check_library_exists("rt" "clock_gettime" "" HAVE_LIBRT)
                if (HAVE_LIBRT)
                    set(HAVE_REALTIME TRUE CACHE INTERNAL "")
                endif ()
                cmake_pop_check_state()
            endif ()
            unset(defines)
        endif ()
        if (HAVE_REALTIME)
            add_library("${target}" INTERFACE IMPORTED)
            if (HAVE_LIBRT)
                set_property(TARGET "${target}" PROPERTY IMPORTED_LIBNAME "rt")
            endif ()
            if (REALTIME_REQUIRED_DEFINITIONS)
                target_compile_definitions("${target}" INTERFACE "${REALTIME_REQUIRED_DEFINITIONS}")
            endif ()
        endif ()
    elseif (WIN32)
        # Look for timeGetTime() in winmm. It is a time source not affected by ACPI and process migration between
        # multiple CPUs like QueryPerformanceCounter. It can have a better resolution than GetTickCount (up to 1ms) and
        # it is not affected by system time changes.
        cmake_push_check_state()
        check_library_exists("winmm" "timeGetTime" "windows.h;timeapi.h" HAVE_REALTIME)
        cmake_pop_check_state()
        if (HAVE_REALTIME)
            add_library("${target}" INTERFACE IMPORTED)
            set_property(TARGET "${target}" PROPERTY IMPORTED_LIBNAME "winmm")
        endif ()
    else ()
        add_library("${target}" INTERFACE IMPORTED)
    endif ()
endif ()

if (TARGET "${target}")
    set(${CMAKE_FIND_PACKAGE_NAME}_FOUND TRUE)
endif ()

find_package_handle_standard_args("${CMAKE_FIND_PACKAGE_NAME}"
        REQUIRED_VARS ${CMAKE_FIND_PACKAGE_NAME}_FOUND
        HANDLE_COMPONENTS)
