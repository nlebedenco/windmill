include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

include(Windmill/Compilers/Common)
include(Windmill/Compilers/${CMAKE_C_COMPILER_ID} OPTIONAL)
