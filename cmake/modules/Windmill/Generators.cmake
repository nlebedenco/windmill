include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

# Report generator used
message(STATUS "CMake generator: ${CMAKE_GENERATOR}")

# Check single-config generator build type is supported.
if (CMAKE_BUILD_TYPE)
    if (DEFINED CMAKE_CONFIGURATION_TYPES)
        set(expected "${CMAKE_CONFIGURATION_TYPES}")
    else ()
        set(expected Debug Release RelWithDebInfo MinSizeRel)
    endif ()
    if (NOT "${CMAKE_BUILD_TYPE}" IN_LIST expected)
        list(JOIN expected "\\\",\\\"" expected)
        message(FATAL_ERROR "Invalid build type: \"${CMAKE_BUILD_TYPE}\" (expected was \"${expected}\")")
    endif ()
    unset(expected)
endif ()

# Default build type for multi-config generators.
get_property(WINDMILL_GENERATOR_IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if (WINDMILL_GENERATOR_IS_MULTI_CONFIG)
    # For multi-config generators the default build type is the first entry in CMAKE_CONFIGURATION_TYPES.
    # It is a common mistake to pass CMAKE_BUILD_TYPE to a configuration using a multi-config generator even though
    # CMake documentation clearly states that CMAKE_BUILD_TYPE is ignored in such cases. In fact, many IDEs pass
    # CMAKE_BUILD_TYPE regardless of the generator used and it can be very confusing for developers so we se
    # CMAKE_BUILD_TYPE as a default for CMAKE_DEFAULT_BUILD_TYPE in multi-config generators that support this.
    # As of CMake 3.29 only Ninja Multi-Config supports CMAKE_DEFAULT_BUILD_TYPE.
    # See https://cmake.org/cmake/help/latest/variable/CMAKE_DEFAULT_BUILD_TYPE.html
    if ("${CMAKE_GENERATOR}" MATCHES "Ninja")
        if (CMAKE_BUILD_TYPE)
            set(CMAKE_DEFAULT_BUILD_TYPE "${CMAKE_BUILD_TYPE}" CACHE STRING "Multi-config generator default build type.")
            set_property(CACHE CMAKE_DEFAULT_BUILD_TYPE PROPERTY STRINGS "${CMAKE_CONFIGURATION_TYPES}")
        endif ()
    endif ()
endif ()

if (WINDMILL_GENERATOR_IS_MULTI_CONFIG)
    list(JOIN CMAKE_CONFIGURATION_TYPES ", " values)
    message(STATUS "Configuration type(s): ${values}")
    unset(values)
else ()
    message(STATUS "Configuration type(s): ${CMAKE_BUILD_TYPE}")
endif ()
