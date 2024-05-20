include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

include(Windmill/Systems/Common)
include(Windmill/Systems/${CMAKE_SYSTEM_NAME} OPTIONAL RESULT_VARIABLE included)
if (NOT included)
    message(STATUS "Could NOT include Windmill/Systems/${CMAKE_SYSTEM_NAME} (CMake module not found)")
endif ()
unset(included)
