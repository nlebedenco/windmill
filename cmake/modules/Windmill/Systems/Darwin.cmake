include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

include(Windmill/Systems/Common)

# Default target system ABI.
# We only really support the MACOS ABI for macOS.
set(WINDMILL_SYSTEM_ABI "macOS")

# Default target system ABI version.
set(WINDMILL_SYSTEM_ABI_VERSION)

# Default target system platform.
set(WINDMILL_SYSTEM_PLATFORM "Apple")

# TODO: Support for macOS desktop
message(FATAL_ERROR "Target system not implemented yet: \"${CMAKE_SYSTEM_NAME}\"")
