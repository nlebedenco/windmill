cmake_minimum_required(VERSION 3.25.0)

########################################################################################################################
# Zephyr Configuration
########################################################################################################################
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})

########################################################################################################################
# Project
########################################################################################################################
# DO NOT simply call the embedded project app. Give it a name in uppercase with a proper prefix so derived CMake
# variables will have safe and reasonable names (e.g. <PROJECT_NAME>_VERSION will become WINDMILL_EMBEDED_APP_VERSION
# instead of app_VERSION).
project(WINDMILL_EMBEDDED_APP LANGUAGES C)

target_sources(app PRIVATE src/main.c)
