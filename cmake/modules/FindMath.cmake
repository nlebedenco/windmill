# This is a special find module to get an imported target for the math library of the target system if any
# (e.g. libm on Linux)
set(${CMAKE_FIND_PACKAGE_NAME}_FOUND FALSE)
set(target "Math::Math")
if (NOT TARGET "${target}")
    # For now assume all unix systems require libm for functions defined in <math.h> except for Apple systems.
    # There's no separate math library on macOS. It's part of the libSystem library, which is always linked in.
    # See https://stackoverflow.com/a/33676633
    # This might change for Linux/GLibc in the near future too just like it has for librt and libpthread.
    if (UNIX AND NOT APPLE)
        cmake_push_check_state()
        check_library_exists("m" "pow" "" HAVE_MATH)
        cmake_pop_check_state()
        if (HAVE_MATH)
            add_library("${target}" INTERFACE IMPORTED)
            set_property(TARGET "${target}" PROPERTY IMPORTED_LIBNAME "m")
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
