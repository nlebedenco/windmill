# This is a special find module to get an imported target for the dynamic loader library of the target system if any
# (e.g. libdl on Linux)
set(${CMAKE_FIND_PACKAGE_NAME}_FOUND FALSE)
set(target "DynamicLoader::DynamicLoader")
if (NOT TARGET "${target}")
    add_library("${target}" INTERFACE IMPORTED)
    # CMake already defines a variable for this we just need to add its value to the target
    if (UNIX AND CMAKE_DL_LIBS)
        set_property(TARGET "${target}" PROPERTY IMPORTED_LIBNAME "${CMAKE_DL_LIBS}")
    endif ()
endif ()

if (TARGET "${target}")
    set(${CMAKE_FIND_PACKAGE_NAME}_FOUND TRUE)
endif ()
unset(target)

find_package_handle_standard_args("${CMAKE_FIND_PACKAGE_NAME}"
        REQUIRED_VARS ${CMAKE_FIND_PACKAGE_NAME}_FOUND
        HANDLE_COMPONENTS)
