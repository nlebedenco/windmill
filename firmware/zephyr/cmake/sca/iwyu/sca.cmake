# This file is configured in firmware/zephyr/module.yml as the entry point for external modules and it is included by
# Zephyr early on in the build configuration.
include_guard(DIRECTORY)
message(STATUS "Including sca.cmake file ${CMAKE_CURRENT_LIST_FILE}")

# Enabling the cache variable before defining the option in shared.cmake has the same effect as if the user had passed
# it via command line.
option(WINDMILL_ENABLE_IWYU "" ON)
