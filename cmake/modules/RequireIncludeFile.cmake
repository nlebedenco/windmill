include(CheckIncludeFile)

# REQUIRE_INCLUDE_FILE(<include> <variable> [<flags>])
# Check if the given <include> header may be included in a C source file and store the result in an internal cache entry
# named <variable>. The optional third argument may be used to add compilation flags to the check (or use CMAKE_REQUIRED_FLAGS
# as described in [CHECK_INCLUDE_FILE](https://cmake.org/cmake/help/latest/module/CheckIncludeFile.html)).
macro(require_include_file include variable)
    check_include_file("${include}" "${variable}" ${ARGN})
    if (NOT ${variable})
        message(FATAL_ERROR "Could NOT find required include file: \"${include}\"")
    endif ()
endmacro()
