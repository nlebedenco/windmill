cmake_path(RELATIVE_PATH CMAKE_CURRENT_SOURCE_DIR BASE_DIRECTORY "${WINDMILL_SOURCE_DIR}" OUTPUT_VARIABLE target)
string(REPLACE "/" "." target "${target}")

add_executable("${target}")
target_sources("${target}" PRIVATE src/main.c)
