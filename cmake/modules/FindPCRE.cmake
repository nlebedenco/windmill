include(Windmill/Functions)

windmill_stage_package("${CMAKE_FIND_PACKAGE_NAME}" HOST)

function(windmill_find_${CMAKE_FIND_PACKAGE_NAME})
    find_path(${CMAKE_FIND_PACKAGE_NAME}_INCLUDE_DIR
            NAMES pcre.h
            NO_SYSTEM_ENVIRONMENT_PATH
            NO_CMAKE_SYSTEM_PATH
            NO_CMAKE_INSTALL_PREFIX
    )
    mark_as_advanced(${CMAKE_FIND_PACKAGE_NAME}_INCLUDE_DIR)
    if (${CMAKE_FIND_PACKAGE_NAME}_INCLUDE_DIR)
        # Find a library for each config.
        # SHOULD only find static libraries assuming CMAKE_FIND_LIBRARY_SUFFIXES is already set up correctly.
        windmill_find_library("${CMAKE_FIND_PACKAGE_NAME}"
                CONFIGURATIONS ${CMAKE_CONFIGURATION_TYPES}
                NAMES "pcre"
                PATHS "${${CMAKE_FIND_PACKAGE_NAME}_INCLUDE_DIR}/.."
        )
        # Find version
        set(${CMAKE_FIND_PACKAGE_NAME}_VERSION "")
        set(header "${${CMAKE_FIND_PACKAGE_NAME}_INCLUDE_DIR}/pcre.h")
        if (${CMAKE_FIND_PACKAGE_NAME}_INCLUDE_DIR AND EXISTS "${header}")
            file(STRINGS "${header}" version REGEX "^[ \t]*#define PCRE_(MAJOR|MINOR)[ \t]+([0-9]+).*$")
            if (version)
                string(REGEX REPLACE "^.*PCRE_MAJOR[ \t]+([0-9]+).*$" "\\1" ${CMAKE_FIND_PACKAGE_NAME}_MAJOR_VERSION "${version}")
                string(REGEX REPLACE "^.*PCRE_MINOR[ \t]+([0-9]+).*$" "\\1" ${CMAKE_FIND_PACKAGE_NAME}_MINOR_VERSION "${version}")
                set(${CMAKE_FIND_PACKAGE_NAME}_PATCH_VERSION 0)
                string(JOIN "." ${CMAKE_FIND_PACKAGE_NAME}_VERSION
                        "${${CMAKE_FIND_PACKAGE_NAME}_MAJOR_VERSION}"
                        "${${CMAKE_FIND_PACKAGE_NAME}_MINOR_VERSION}"
                        "${${CMAKE_FIND_PACKAGE_NAME}_PATCH_VERSION}"
                )
            endif ()
            unset(version)
        endif ()
        propagate(${CMAKE_FIND_PACKAGE_NAME}_VERSION)

        # Only the release library is absolutely required
        set(${CMAKE_FIND_PACKAGE_NAME}_LIBRARY "${${CMAKE_FIND_PACKAGE_NAME}_LIBRARY_RELEASE}")
        propagate(${CMAKE_FIND_PACKAGE_NAME}_LIBRARY)
    endif ()

    find_package_handle_standard_args("${CMAKE_FIND_PACKAGE_NAME}"
            REQUIRED_VARS "${CMAKE_FIND_PACKAGE_NAME}_INCLUDE_DIR" "${CMAKE_FIND_PACKAGE_NAME}_LIBRARY"
            VERSION_VAR "${CMAKE_FIND_PACKAGE_NAME}_VERSION"
            HANDLE_COMPONENTS
    )
    propagate(${CMAKE_FIND_PACKAGE_NAME}_FOUND)

    if (${CMAKE_FIND_PACKAGE_NAME}_FOUND)
        set(target "${CMAKE_FIND_PACKAGE_NAME}::${CMAKE_FIND_PACKAGE_NAME}")
        if (NOT TARGET "${target}")
            add_library("${target}" STATIC IMPORTED)
            set_target_properties("${target}" PROPERTIES IMPORTED_LINK_INTERFACE_LANGUAGES "C")
            target_compile_definitions("${target}" PCRE_STATIC)
            target_include_directories("${target}" INTERFACE "${${CMAKE_FIND_PACKAGE_NAME}_INCLUDE_DIR}")
            foreach (config ${CMAKE_CONFIGURATION_TYPES})
                string(TOUPPER "${config}" config)
                if (${CMAKE_FIND_PACKAGE_NAME}_LIBRARY_${config})
                    if (NOT ${CMAKE_FIND_PACKAGE_NAME}_FIND_QUIETLY)
                        list(APPEND CMAKE_MESSAGE_INDENT "  ")
                        find_package_message("${target}_${config}"
                                "${target} ${config} - ${${CMAKE_FIND_PACKAGE_NAME}_LIBRARY_${config}}"
                                "[${${CMAKE_FIND_PACKAGE_NAME}_LIBRARY_${config}}]"
                        )
                        list(POP_BACK CMAKE_MESSAGE_INDENT)
                    endif ()
                    set_property(TARGET "${target}" APPEND PROPERTY IMPORTED_CONFIGURATIONS "${config}")
                    set_target_properties("${target}" PROPERTIES
                            IMPORTED_LOCATION_${config} "${${CMAKE_FIND_PACKAGE_NAME}_LIBRARY_${config}}"
                    )
                else ()
                    # Missing configs should fallback to Release
                    set_target_properties("${target}" PROPERTIES MAP_IMPORTED_CONFIG_${config} RELEASE)
                endif ()
            endforeach ()
        endif ()
        unset(target)
    endif ()
endfunction()
cmake_language(CALL "windmill_find_${CMAKE_FIND_PACKAGE_NAME}")
