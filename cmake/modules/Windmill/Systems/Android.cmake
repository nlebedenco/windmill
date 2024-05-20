include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

include(Windmill/Systems/Common)

# Target system ABI.
# This is determined by the CMAKE_ANDROID_ARCH_ABI variable.
if ("${CMAKE_ANDROID_ARCH_ABI}" MATCHES "armeabi")
    set(WINDMILL_SYSTEM_ABI "EABI")
else ()
    set(WINDMILL_SYSTEM_ABI "Android")
endif ()

# Target system ABI version.
set(WINDMILL_SYSTEM_ABI_VERSION "${CMAKE_SYSTEM_VERSION}")

# Target system platform.
# For now, any Android machine is considered Mobile even if it is workstation.
set(WINDMILL_SYSTEM_PLATFORM "Mobile")

# Check minimum Android SDK/API level.
if (NOT "${CMAKE_SYSTEM_VERSION}" VERSION_GREATER_EQUAL "${WINDMILL_ANDROID_MINIMUM_VERSION}")
    message(FATAL_ERROR "Invalid target system version: \"${CMAKE_SYSTEM_VERSION}\""
            " (expected >= \"${WINDMILL_ANDROID_MINIMUM_VERSION}\"")
endif ()
