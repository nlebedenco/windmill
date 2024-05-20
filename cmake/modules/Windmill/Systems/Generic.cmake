include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

include(Windmill/Systems/Common)

# Check minimum system version.
if (NOT "${Zephyr-Kernel_VERSION}" VERSION_GREATER_EQUAL "${CMAKE_SYSTEM_VERSION}")
    message(FATAL_ERROR "Could NOT find a suitable ${WINDMILL_NAME} project"
            " (found version \"${Zephyr-Kernel_VERSION}\", but minimum required is \"${CMAKE_SYSTEM_VERSION}\")")
endif ()

# Target system ABI.
# We only really support the ELF ABI for Windmill but we can be more strict when the target is ARM.
if ("${CMAKE_SYSTEM_PROCESSOR}" MATCHES "^([Aa][Rr][Mm])$")
    set(WINDMILL_SYSTEM_ABI "EABI")
else ()
    set(WINDMILL_SYSTEM_ABI "ELF")
endif ()

# Target system ABI version.
set(WINDMILL_SYSTEM_ABI_VERSION "${Zephyr-Kernel_VERSION_MAJOR}.${Zephyr-Kernel_VERSION_MINOR}")

# Nothing can be assumed about generic system platforms.
set(WINDMILL_SYSTEM_PLATFORM "Unknown")

# FIXME: Force the global property TARGET_SUPPORTS_SHARED_LIBS to false for non-Xtensa architectures.
#        This is here because upstream Zephyr (pre 3.7.0) accepted a PR that affected CMAKE_SYSTEM_NAME and this
#        property without fully considering the impact on non-trivial projects. Apparently, the .llext loader for Xtensa
#        relies on shared libraries instead of the object file format so TARGET_SUPPORTS_SHARED_LIBS must be true in
#        that case but not for any other architecture.
#
#        Since https://github.com/zephyrproject-rtos/zephyr/pull/67997, Zephyr assigns CMAKE_SYSTEM_NAME to "Zephyr" in
#        FindTargetTools.cmake and adds a custom platform CMake module only to set the global property
#        TARGET_SUPPORTS_SHARED_LIBS (and arguably even does it wrong!). Those changes broke the presumption that
#        "Generic" is the system name corresponding to Zephyr and also failed to ensure a consistent value for
#        CMAKE_SYSTEM_NAME because a top-level project defined before the first call to `find_package(Zephyr)` will not
#        find `<ZEPHYR_BASE>/cmake/modules/Platform/Zephyr.cmake` which in turn leads CMake to guess the value of
#        CMAKE_SYSTEM_NAME to be either a manually-specified CMAKE_SYSTEM_NAME (if any) or the same as
#        CMAKE_HOST_SYSTEM_NAME. Only for the first call to `find_package(Zephyr)` to change CMAKE_SYSTEM_NAME again
#        to "Zephyr". There is at least one PR that proposes a fix and is pending review/approval.
#
#        This block may be removed if/when CMAKE_SYSTEM_NAME turns back to being "Generic".
#        See https://cmake.org/cmake/help/v3.25/prop_gbl/TARGET_SUPPORTS_SHARED_LIBS.html
#        See https://github.com/zephyrproject-rtos/zephyr/pull/67997
#        See https://github.com/zephyrproject-rtos/zephyr/pull/71468
if (NOT CONFIG_XTENSA)
    set_property(GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS false)
endif ()
