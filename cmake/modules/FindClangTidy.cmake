include(Windmill/Functions)

windmill_stage_package("${CMAKE_FIND_PACKAGE_NAME}" HOST)

function(windmill_find_package_${CMAKE_FIND_PACKAGE_NAME})
    # If compiler is Clang search in the compiler folder first.
    # The expected search order is:
    #
    #     <compiler folder> -> ${CMAKE_FIND_PACKAGE_NAME}_ROOT -> CMAKE_PREFIX_PATH/[s]bin -> CMAKE_PROGRAM_PATH -> PATHS
    #
    # so we will look for the program in the virtual environment first, followed by stage folder, compiler folder (if
    # the compiler is Clang) and only then fallback to the host system path.
    if ("${CMAKE_C_COMPILER_ID}" STREQUAL "Clang")
        cmake_path(GET CMAKE_C_COMPILER PARENT_PATH path)
        find_program(${CMAKE_FIND_PACKAGE_NAME}_EXECUTABLE
                NAMES clang-tidy
                PATHS ${path}
                DOC "Path to ${CMAKE_FIND_PACKAGE_NAME}"
                NO_DEFAULT_PATH
                NO_CMAKE_FIND_ROOT_PATH
        )
        unset(path)
    endif ()
    find_program(${CMAKE_FIND_PACKAGE_NAME}_EXECUTABLE
            NAMES clang-tidy
            NAMES_PER_DIR
            DOC "Path to ${CMAKE_FIND_PACKAGE_NAME}"
    )
    unset(hints)
    set(${CMAKE_FIND_PACKAGE_NAME}_REASON_FAILURE_MESSAGE)
    if (${CMAKE_FIND_PACKAGE_NAME}_EXECUTABLE)
        execute_process(
                COMMAND "${${CMAKE_FIND_PACKAGE_NAME}_EXECUTABLE}" --version
                RESULT_VARIABLE exitcode
                OUTPUT_VARIABLE version
                ERROR_VARIABLE error
        )
        # Find version
        set(${CMAKE_FIND_PACKAGE_NAME}_VERSION "")
        if (exitcode EQUAL 0)
            set(regex "LLVM version ([0-9]+\\.[0-9]+\\.[0-9]+)")
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
