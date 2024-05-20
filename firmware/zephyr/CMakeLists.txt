# This file is defined as the module's entry point for CMake in zephyr/module.yml and gets added by Zephyr AFTER
# parsing Kconfig files.
########################################################################################################################
# General Configuration
########################################################################################################################
include(CMakePrintHelpers)

########################################################################################################################
# Zephyr Configuration
########################################################################################################################
# This is needed so that custom driver classes using system calls are taken into
# account by scripts/build/gen_syscalls.py.
# See https://github.com/zephyrproject-rtos/zephyr/pull/71132
# See https://github.com/zephyrproject-rtos/zephyr/issues/20140
# See https://github.com/zephyrproject-rtos/zephyr/pull/21268
zephyr_syscall_include_directories(include)

zephyr_include_directories(include)

########################################################################################################################
# Sources
########################################################################################################################
add_subdirectory(drivers)
add_subdirectory(lib)
