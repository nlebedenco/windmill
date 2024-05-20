include(Windmill/Functions)

windmill_stage_package("${CMAKE_FIND_PACKAGE_NAME}" HOST)

function(windmill_find_package_${CMAKE_FIND_PACKAGE_NAME})
    find_program(${CMAKE_FIND_PACKAGE_NAME}_EXECUTABLE
            NAMES "cppcheck"
            NO_CMAKE_INSTALL_PREFIX
    )
    mark_as_advanced(${CMAKE_FIND_PACKAGE_NAME}_EXECUTABLE)

    set(${CMAKE_FIND_PACKAGE_NAME}_REASON_FAILURE_MESSAGE)
    if (${CMAKE_FIND_PACKAGE_NAME}_EXECUTABLE)
        execute_process(
                COMMAND "${${CMAKE_FIND_PACKAGE_NAME}_EXECUTABLE}" --version
                RESULT_VARIABLE exitcode
                OUTPUT_VARIABLE version
                ERROR_VARIABLE error
        )
        # Parse version
        if (exitcode EQUAL 0)
            set(regex "^[Cc]ppcheck ([0-9]+\\.[0-9]+(\\.[0-9]+)?)")
            string(REGEX MATCH "${regex}" version "${version}")
            string(REGEX REPLACE "${regex}" "\\1" ${CMAKE_FIND_PACKAGE_NAME}_VERSION "${version}")
        else ()
            set(${CMAKE_FIND_PACKAGE_NAME}_REASON_FAILURE_MESSAGE REASON_FAILURE_MESSAGE "${error}")
            set(${CMAKE_FIND_PACKAGE_NAME}_VERSION "NOTFOUND")
        endif ()
        set(${CMAKE_FIND_PACKAGE_NAME}_VERSION "${${CMAKE_FIND_PACKAGE_NAME}_VERSION}" PARENT_SCOPE)
    endif ()
    find_package_handle_standard_args("${CMAKE_FIND_PACKAGE_NAME}"
            REQUIRED_VARS
            ${CMAKE_FIND_PACKAGE_NAME}_EXECUTABLE
            VERSION_VAR
            ${CMAKE_FIND_PACKAGE_NAME}_VERSION
            HANDLE_COMPONENTS
            ${${CMAKE_FIND_PACKAGE_NAME}_REASON_FAILURE_MESSAGE}
    )
    set(${CMAKE_FIND_PACKAGE_NAME}_FOUND "${${CMAKE_FIND_PACKAGE_NAME}_FOUND}" PARENT_SCOPE)
endfunction()
cmake_language(CALL "windmill_find_package_${CMAKE_FIND_PACKAGE_NAME}")
