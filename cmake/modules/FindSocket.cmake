# This is a special find module to get an imported target for the socket library of the target system if any
# (e.g. ws2_32 on Windows)
set(${CMAKE_FIND_PACKAGE_NAME}_FOUND FALSE)
set(target "Socket::Socket")
if (NOT TARGET "${target}")
    if (WIN32)
        cmake_push_check_state()
        check_library_exists("ws2_32" "socket" "windows.h;winsock2.h" HAVE_SOCKET)
        cmake_pop_check_state()
        if (HAVE_SOCKET)
            add_library("${target}" INTERFACE IMPORTED)
            set_property(TARGET "${target}" PROPERTY IMPORTED_LIBNAME "ws2_32")
        endif ()
    else ()
        add_library("${target}" INTERFACE IMPORTED)
    endif ()
endif ()

if (TARGET "${target}")
    set(${CMAKE_FIND_PACKAGE_NAME}_FOUND TRUE)
endif ()
unset(target)

find_package_handle_standard_args("${CMAKE_FIND_PACKAGE_NAME}"
        REQUIRED_VARS ${CMAKE_FIND_PACKAGE_NAME}_FOUND
        HANDLE_COMPONENTS)
