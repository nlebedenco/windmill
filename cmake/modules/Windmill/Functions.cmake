include_guard(DIRECTORY)

# NOTE: When using cmake_parse_arguments() it is recommended to always pass ${CMAKE_CURRENT_FUNCTION} as prefix
#       to avoid argument parse variables from leaking into nested function calls by accident. Consider this script:
#       ```
#           function(bar)
#               cmake_parse_arguments("" "" "A;B;C" "" ${ARGN})
#               cmake_print_variables(_A _B _C)
#           endfunction()
#
#           function(foo)
#               cmake_parse_arguments("" "A;B" "" "" ${ARGN})
#               cmake_print_variables(_A _B)
#               function(bar C "hello")
#           endfunction()
#
#           # Now if we call foo() passing A it will see _A set to TRUE and _B set to FALSE but contrary to expectations
#           # the nested call to bar() will have it see _A = TRUE, _B = FALSE and _C = "hello" because the scope of the
#           # call inherits those variables from foo. Normally a developer would have expected that a call such as
#           # bar(C hello) would have seen _A and _B undefined instead.
#           foo(A)
#       ```
#       For the same reason we must also unset local variables as soon as possible inside functions and make sure that
#       all local variables are initialized before first use. CMake can warn us of undefined variables but it cannot
#       distinguish a local variable from an accidentally leaked one.

macro(windmill_function_incorrect_arguments)
    message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} Function invoked with incorrect arguments"
            " for function named: ${CMAKE_CURRENT_FUNCTION}")
endmacro()

macro(windmill_function_assert_exact_number_of_arguments expected actual)
    if (NOT "${expected}" EQUAL "${actual}")
        windmill_function_incorrect_arguments()
    endif ()
endmacro()

macro(windmill_function_assert_maximum_number_of_arguments expected actual)
    if (NOT "${expected}" GREATER_EQUAL "${actual}")
        windmill_function_incorrect_arguments()
    endif ()
endmacro()

macro(windmill_function_assert_minimum_number_of_arguments expected actual)
    if (NOT "${expected}" LESS_EQUAL "${actual}")
        windmill_function_incorrect_arguments()
    endif ()
endmacro()

macro(windmill_function_require_arguments)
    foreach (argument IN ITEMS ${ARGN})
        # We cannot simply check `if(NOT ${argument})` because a boolean argument set to false would appear as not
        # passed when in fact it was.
        if (NOT DEFINED ${argument})
            windmill_function_incorrect_arguments()
        endif ()
        # Must check for empty serparately to avoid warnings when --warn-undefined is passed.
        if ("${argument}" STREQUAL "")
            windmill_function_incorrect_arguments()
        endif ()
    endforeach ()
endmacro()

macro(windmill_function_refuse_arguments)
    foreach (argument IN ITEMS ${ARGN})
        if (DEFINED ${argument})
            windmill_function_incorrect_arguments()
        endif ()
    endforeach ()
endmacro()

# Set up a watcher to detect unintentional modifications of a scope variable and raise a fatal error. This effectively
# marks a scope variable as read-only. Note this function only applies to scope variables and will not prevent a cache
# variable from being set or forcebly changed.
function(windmill_mark_as_readonly variable)
    function(${CMAKE_CURRENT_FUNCTION}_write_protected variable access value current_list_file)
        if (access STREQUAL "MODIFIED_ACCESS")
            message(FATAL_ERROR "Invalid attempt to change the scope value of a read-only variable: \"${variable}\".")
        endif ()
    endfunction()
    variable_watch(${variable} "${CMAKE_CURRENT_FUNCTION}_write_protected")
endfunction()

# Define variables in the parent scope. If the variable is cached, the cache value is used to initialize it. Otherwise
# the variable is initialized with an empty string. A variable will be unaffected if it is already a scope variable.
function(windmill_declare_variables)
    foreach (variable IN LISTS ARGN)
        if (DEFINED ${variable})
            set(${variable} "${${variable}}" PARENT_SCOPE)
        else ()
            set(${variable} "" PARENT_SCOPE)
        endif ()
    endforeach ()
endfunction()

# Check that all provided variables are defined and mark their scope values as read-only.
function(windmill_require_variables)
    set(undefined)
    foreach (variable IN LISTS ARGN)
        if (NOT DEFINED ${variable})
            list(APPEND undefined ${variable})
        endif ()
        windmill_mark_as_readonly(${variable})
    endforeach ()
    if (undefined)
        list(SORT undefined)
        string(REPLACE ";" "\n    " undefined "${undefined}")
        message(FATAL_ERROR "Undefined variable(s):\n    ${undefined}")
    endif ()
    unset(undefined)
endfunction()

function(windmill_warn_cache_variables_overriden)
    set(overriden)
    foreach (variable IN LISTS ARGN)
        if (DEFINED CACHE{${variable}})
            list(APPEND overriden ${variable})
        endif ()
    endforeach ()
    if (overriden)
        list(SORT overriden)
        list(JOIN overriden "\n    " redefined)
        message(WARNING "Manually-specified variables overriden by the project:\n    ${overriden}")
    endif ()
    unset(overriden)
endfunction()

function(windmill_compiler_minimum_version compiler version)
    windmill_function_assert_exact_number_of_arguments(2 ${ARGC})
    string(STRIP "${compiler}" compiler)
    string(STRIP "${version}" version)
    windmill_function_require_arguments(compiler version)
    foreach (lang IN ITEMS C CXX)
        if ("${CMAKE_${lang}_COMPILER_ID}" STREQUAL "${compiler}")
            if (NOT "${CMAKE_${lang}_COMPILER_VERSION}" VERSION_GREATER_EQUAL "${version}")
                message(FATAL_ERROR "Invalid compiler (found version \"${CMAKE_${lang}_COMPILER_VERSION}\")"
                        " (Required is at least version \"${version}\")\n"
                        "    Reason given by configuration:\n"
                        "        Compiler: Wrong version for the compiler \"${CMAKE_${lang}_COMPILER}\""
                )
            endif ()
        endif ()
    endforeach ()
endfunction()

# Get the canonical processor name.
function(windmill_get_canonical_processor variable processor)
    windmill_function_assert_exact_number_of_arguments(2 ${ARGC})
    string(STRIP "${variable}" variable)
    string(STRIP "${processor}" processor)
    windmill_function_require_arguments(variable processor)
    if ("${processor}" MATCHES "^([Xx]86_64|[Aa][Mm][Dd]64|[Xx]64)$")
        set(canonical "x86_64")
    elseif ("${processor}" MATCHES "^([Aa][Aa][Rr][Cc][Hh]64)$")
        set(canonical "arm64")
    else ()
        string(TOLOWER "${processor}" canonical)
    endif ()
    set(${variable} "${canonical}" PARENT_SCOPE)
endfunction()

# Get the triplet of the target system.
function(windmill_triplet)
    cmake_parse_arguments("${CMAKE_CURRENT_FUNCTION}" "" "PROCESSOR;PLATFORM;NAME;ABI;OUTPUT_VARIABLE" "" ${ARGN})
    windmill_function_require_arguments(
            ${CMAKE_CURRENT_FUNCTION}_PROCESSOR
            ${CMAKE_CURRENT_FUNCTION}_PLATFORM
            ${CMAKE_CURRENT_FUNCTION}_NAME
            ${CMAKE_CURRENT_FUNCTION}_OUTPUT_VARIABLE
    )
    windmill_function_refuse_arguments(${CMAKE_CURRENT_FUNCTION}_UNPARSED_ARGUMENTS)
    foreach (variable IN ITEMS
            ${CMAKE_CURRENT_FUNCTION}_PROCESSOR
            ${CMAKE_CURRENT_FUNCTION}_PLATFORM
            ${CMAKE_CURRENT_FUNCTION}_NAME)
        string(STRIP "${${variable}}" ${variable})
        string(TOLOWER "${${variable}}" ${variable})
    endforeach ()
    # ABI is optional
    if (NOT ${CMAKE_CURRENT_FUNCTION}_ABI)
        set(${CMAKE_CURRENT_FUNCTION}_ABI "${${CMAKE_CURRENT_FUNCTION}_NAME}")
    else ()
        string(STRIP "${${CMAKE_CURRENT_FUNCTION}_ABI}" ${CMAKE_CURRENT_FUNCTION}_ABI)
        string(TOLOWER "${${CMAKE_CURRENT_FUNCTION}_ABI}" ${CMAKE_CURRENT_FUNCTION}_ABI)
    endif ()
    # Use the canonical processor name
    windmill_get_canonical_processor(${CMAKE_CURRENT_FUNCTION}_PROCESSOR "${${CMAKE_CURRENT_FUNCTION}_PROCESSOR}")
    # Special case for macOS which CMake reports as "Darwin"
    if ("${${CMAKE_CURRENT_FUNCTION}_NAME}" MATCHES "^[Dd][Aa][Rr][Ww][Ii][Nn]$")
        set(${CMAKE_CURRENT_FUNCTION}_NAME "macOS")
    endif ()
    # Sanitize triplet components first
    foreach (variable IN ITEMS
            ${CMAKE_CURRENT_FUNCTION}_PROCESSOR
            ${CMAKE_CURRENT_FUNCTION}_PLATFORM
            ${CMAKE_CURRENT_FUNCTION}_NAME
            ${CMAKE_CURRENT_FUNCTION}_ABI
    )
        string(REGEX REPLACE "[;-]" "_" ${variable} "${${variable}}")
    endforeach ()
    # Construct list by expanding variables unquoted to omit empty strings
    set(triplet ${${CMAKE_CURRENT_FUNCTION}_PROCESSOR} ${${CMAKE_CURRENT_FUNCTION}_PLATFORM} ${${CMAKE_CURRENT_FUNCTION}_NAME})
    # ABI can be omitted if it is equal to NAME
    if (NOT "${${CMAKE_CURRENT_FUNCTION}_ABI}" STREQUAL "${${CMAKE_CURRENT_FUNCTION}_NAME}")
        set(triplet ${triplet} ${${CMAKE_CURRENT_FUNCTION}_ABI})
    endif ()
    # Join the list
    list(JOIN triplet "-" triplet)
    set(${${CMAKE_CURRENT_FUNCTION}_OUTPUT_VARIABLE} "${triplet}" PARENT_SCOPE)
    unset(triplet)
endfunction()

# Get git property from a specified clone path.
function(windmill_get_git_property variable path property)
    windmill_function_assert_exact_number_of_arguments(3 ${ARGC})
    string(STRIP "${variable}" variable)
    string(STRIP "${path}" path)
    string(STRIP "${property}" property)
    windmill_function_require_arguments(variable path property)

    macro(${CMAKE_CURRENT_FUNCTION}_GET_GIT)
        find_package(Git REQUIRED)
        # AVOID use of `git -C` with absolute paths. Set the WORKING_DIRECTORY instead because in WSL we may pick up the
        # Windows git client which does not understand Linux mount points.
        execute_process(
                COMMAND "${GIT_EXECUTABLE}" ${ARGN}
                WORKING_DIRECTORY "${path}"
                RESULT_VARIABLE result
                OUTPUT_VARIABLE output
                ERROR_QUIET
        )
        if (NOT result EQUAL 0)
            set(output "${variable}-NOTFOUND")
        endif ()
        string(STRIP "${output}" output)
        set(${variable} "${output}" PARENT_SCOPE)
        unset(output)
        unset(result)
    endmacro()

    if ("${property}" STREQUAL "ORIGIN")
        cmake_language(CALL ${CMAKE_CURRENT_FUNCTION}_GET_GIT
                "remote" "get-url" "origin")
    elseif ("${property}" STREQUAL "REVISION")
        cmake_language(CALL ${CMAKE_CURRENT_FUNCTION}_GET_GIT
                "describe" "--tags" "--always" "--long" "--dirty" "--broken")
    elseif ("${property}" STREQUAL "COMMIT")
        cmake_language(CALL ${CMAKE_CURRENT_FUNCTION}_GET_GIT
                "rev-parse" "HEAD")
    else ()
        windmill_function_incorrect_arguments()
    endif ()
endfunction()

# Declare a package potentially sourced in WINDMILL_PACKAGES_SOURCE_DIR.
#
# Packages declared with this function may be staged and will be automatically built and archived if necessary.
# This is not a general-purpose package management solution and is only meant for the Windmill project itself.
#
# The version argument is used to define the cache variable <PackageName>_FIND_VERSION which then serves as a default
# version for further calls to find_package() that do not specify a minimum a version. There is no support for exact
# version matches or version ranges because of CMake limitations on how to communicate defaults to find_package().
#
# HOST indicates this package is only meant to be used by the host system and will not provide build artifacts to be
# consumed for the target system such as include headers or libraries. This is particularly significant when
# cross-compiling.
#
# NO_BUILD disables automatic building and archiving.
#
# Example Usage:
#     windmill_declare_package(Git 2.43 HOST NO_BUILD)
#     windmill_declare_package(IWYU 0.21 HOST)
#     windmill_declare_package(ZLIB 1.3)
#
function(windmill_declare_package package version)
    cmake_parse_arguments("${CMAKE_CURRENT_FUNCTION}" "EXACT;HOST;NO_BUILD" "" "" ${ARGN})
    windmill_function_refuse_arguments(${CMAKE_CURRENT_FUNCTION}_UNPARSED_ARGUMENTS)
    string(STRIP "${package}" package)
    string(STRIP "${version}" version)
    windmill_function_require_arguments(package version)

    if (${package}_FIND_VERSION AND ${CMAKE_CURRENT_FUNCTION}_VERSION)
        if (NOT "${${package}_FIND_VERSION}" STREQUAL "${${CMAKE_CURRENT_FUNCTION}_VERSION}")
            message(WARNING "Previously specified variable will override default minimum version declared for package \"${package}\"\n"
                    "    ${package}_FIND_VERSION=${${package}_FIND_VERSION}")
        endif ()
    endif ()
    set(${package}_FIND_VERSION "${version}" CACHE STRING "")

    if (${CMAKE_CURRENT_FUNCTION}_NO_BUILD)
        set(WINDMILL_BUILD_PACKAGE_${package} OFF CACHE BOOL "")
    endif ()

    if (${CMAKE_CURRENT_FUNCTION}_HOST)
        set(${CMAKE_CURRENT_FUNCTION}_HOST "HOST")
    else ()
        set(${CMAKE_CURRENT_FUNCTION}_HOST)
    endif ()
    windmill_build_package("${package}" ${${CMAKE_CURRENT_FUNCTION}_HOST})
endfunction()

# Get the path to a package archive that best matches the target triplet and ABI version specified. If such a package
# archive does not exist <variable> will be assigned the string <package>-NOTFOUND.
#
# Example Usage:
#     windmill_select_package(IWYU_PACKAGE_ARCHIVE_PATH IWYU x86_64-pc-windows-msvc 14.38)
#
function(windmill_select_package variable package triplet abiversion)
    windmill_function_assert_exact_number_of_arguments(4 ${ARGC})
    string(STRIP "${variable}" variable)
    windmill_function_require_arguments(variable)

    set(result "${package}-NOTFOUND")

    # Package archive names are all lower case.
    string(TOLOWER "${package}" basename)
    # Find all archives matching the package name and triplet
    file(GLOB archives LIST_DIRECTORIES FALSE RELATIVE "${WINDMILL_PACKAGES_DIR}"
            "${WINDMILL_PACKAGES_DIR}/${basename}-${triplet}*.tgz")
    unset(basename)
    # It's safest to use a broad regex to match ${submodule}-${triplet} here to avoid the risk of any unescaped regex
    # character affecting the operation.
    list(FILTER archives INCLUDE REGEX "^([-_.0-9a-zA-Z]+)([0-9]+(\\.[0-9]+(\\.[0-9]+)?)?)?\\.tgz$")
    list(SORT archives COMPARE NATURAL ORDER DESCENDING)
    # Pick the latest version of all compatible archives found.
    foreach (candidate IN LISTS archives)
        # Cannot use string(REGEX REPLACE) when there are one or more optional capture groups because CMake
        # generates an error and absent captures are referenced in the replace expresion.
        if ("${candidate}" MATCHES "^(.+-[a-z]+)([0-9]+(\\.[0-9]+(\\.[0-9]+)?)?)?\\.tgz$")
            if ("${CMAKE_MATCH_2}" VERSION_LESS_EQUAL "${abiversion}")
                cmake_path(SET result NORMALIZE "${WINDMILL_PACKAGES_DIR}/${candidate}")
                break()
            endif ()
        endif ()
    endforeach ()
    unset(archives)
    set(${variable} "${result}" PARENT_SCOPE)
endfunction()

# Build package from WINDMILL_PACKAGES_SOURCE_DIR if necessary. The build will be skipped if a package archive
# already exists that matches the signature of the package source directory.
#
# All package names correspond to a submodule folder under WINDMILL_PACKAGES_SOURCE_DIR that MUST BE comprised
# only of alphanumeric lower-case characters (i.e. 0-9, a-z). This base name is also used to compose the package
# name.
#
# HOST indicates this package is only meant to be used by the host system. This is particularly significant when
# cross-compiling. Since CMake cannot be configured with more than one system we can only build a package intended
# for the host if it is also the target system.
#
# Example Usage:
#     windmill_build_package(IWYU HOST)
#
function(windmill_build_package package)
    cmake_parse_arguments("${CMAKE_CURRENT_FUNCTION}" "HOST" "" "" ${ARGN})
    windmill_function_refuse_arguments(${CMAKE_CURRENT_FUNCTION}_UNPARSED_ARGUMENTS)
    string(STRIP "${package}" package)
    windmill_function_require_arguments(package)

    if (${CMAKE_CURRENT_FUNCTION}_HOST)
        set(triplet "${WINDMILL_HOST_SYSTEM_TRIPLET}")
        set(abi_version "${WINDMILL_HOST_SYSTEM_ABI_VERSION}")
    else ()
        set(triplet "${WINDMILL_SYSTEM_TRIPLET}")
        set(abi_version "${WINDMILL_SYSTEM_ABI_VERSION}")
    endif ()

    set(error_msg "Could NOT build ${package} for ${triplet}")

    # All package names correspond to a submodule folder under WINDMILL_PACKAGES_SOURCE_DIR that MUST BE comprised
    # only of alphanumeric lower-case characters (i.e. 0-9, a-z). This base name is also used to compose the package
    # name.
    string(TOLOWER "${package}" basename)

    # Break early if the package is explicitly not allowed to build. This is checked before the control list and not
    # after so one can still override this variable and try again at any point of the configuration phase.
    if (DEFINED WINDMILL_BUILD_PACKAGE_${package} AND NOT WINDMILL_BUILD_PACKAGE_${package})
        return()
    endif ()

    # Check if we have already tried to build this package to avoid multiple attempts in case of build errors.
    set(stamp "${basename}@${triplet}")
    get_property(list GLOBAL PROPERTY "WINDMILL_PACKAGES_BUILT")
    if ("${stamp}" IN_LIST list)
        return()
    endif ()
    unset(list)

    # Mark package as built.
    set_property(GLOBAL APPEND PROPERTY "WINDMILL_PACKAGES_BUILT" "${stamp}")
    unset(stamp)

    # Search for a compatible package before trying to build (i.e. one for an older ABI version). There is no
    # need to build if a compatible package exists already.
    windmill_select_package(PACKAGE_ARCHIVE "${package}"
            "${triplet}"
            "${abi_version}")

    # Define a generator to use with packages that support CMake.
    # This MUST BE a single-config generator compatible with Windows, Linux and Darwin.
    set(PACKAGE_GENERATOR Ninja)

    # Define base package build folders
    cmake_path(SET PACKAGE_SOURCE_DIR NORMALIZE "${WINDMILL_PACKAGES_SOURCE_DIR}/${basename}")
    cmake_path(SET PACKAGE_BINARY_DIR NORMALIZE "${WINDMILL_PACKAGES_BINARY_DIR}/${basename}")
    cmake_path(SET PACKAGE_OUTPUT_DIR NORMALIZE "${WINDMILL_PACKAGES_BINARY_DIR}/${basename}/${WINDMILL_SYSTEM_TRIPLET}")

    cmake_path(RELATIVE_PATH PACKAGE_SOURCE_DIR BASE_DIRECTORY "${WINDMILL_SOURCE_DIR}" OUTPUT_VARIABLE PACKAGE_RELATIVE_PATH)

    # Get the package sources origin and revision
    windmill_get_git_property(PACKAGE_COMMIT "${PACKAGE_SOURCE_DIR}" "COMMIT")
    windmill_get_git_property(PACKAGE_REVISION "${PACKAGE_SOURCE_DIR}" "REVISION")
    windmill_get_git_property(PACKAGE_ORIGIN "${PACKAGE_SOURCE_DIR}" "ORIGIN")

    # If archive already exists and both origin and revision match then there is no need to build anything.
    if (EXISTS "${PACKAGE_ARCHIVE}")
        file(ARCHIVE_EXTRACT
                INPUT "${PACKAGE_ARCHIVE}"
                DESTINATION "${WINDMILL_PACKAGES_BINARY_DIR}/${basename}/found"
                PATTERNS "${triplet}/${basename}.json"
        )
        file(READ "${WINDMILL_PACKAGES_BINARY_DIR}/${basename}/found/${triplet}/${basename}.json" json)
        string(JSON commit GET "${json}" "commit")
        string(JSON path GET "${json}" "path")
        string(JSON revision GET "${json}" "revision")
        string(JSON url GET "${json}" "url")
        set(expected "${PACKAGE_COMMIT} ${PACKAGE_RELATIVE_PATH} (${PACKAGE_REVISION}) ${PACKAGE_ORIGIN}")
        # If archive revision matches the source directory there is nothing else to do.
        if ("${expected}" STREQUAL "${commit} ${path} (${revision}) ${url}")
            return()
        endif ()
        message(STATUS "Found the ${package} submodule has a new revision: ${expected}")
        unset(expected)
        unset(url)
        unset(revision)
        unset(path)
        unset(commit)
    endif ()

    # Building a package for the host requires the target system triplet to match.
    # Ideally we should be able to compile a package for any arbitrary triplet as long as the correct compiler and
    # flags can be determined. The problem is ensuring a consistent mechanism to do so without increasing the complexity
    # of the build scripts too much. For one, CMake cannot build for different HOST and TARGET triplets in a single
    # instance. Cross-compiling can only build artifacts for the target system so we would have to invoke a different
    # CMake instance to build for the host and pass cache variables (or a toolchain file) corresponding to the host
    # triplet (specific compiler, compiler flags...). Any required configuration checks would need to run separately and
    # only then we would be able to invoke the commands that tap into the package's own build scripts whatever they are.
    # It would also be much harder for a user to specify overrides (compiler or flags) since we would have to define a
    # separate set of variables just for the host. For example, setting CMAKE_<lang>_COMPILER would not be enough
    # anymore as though it might work with the target system, it might not for the host. And finally, a general
    # depedency management system is far out-of-scope of this project. Should this ever become a problem we might
    # consider using and open-source solution such as vcpkg or conan.io. Notice however that none of these solutions
    # would be free of side-effects and might impose different restrictions.
    if (NOT "${triplet}" STREQUAL "${WINDMILL_SYSTEM_TRIPLET}")
        message(STATUS "${error_msg} (target system triplet is \"${WINDMILL_SYSTEM_TRIPLET}\")")
        return()
    endif ()
    unset(triplet)
    unset(abi_version)

    # We always build the package for the current triplet. This is important because a compatible package could have
    # been found but still be out-of-date.
    cmake_path(SET PACKAGE_ARCHIVE NORMALIZE "${WINDMILL_PACKAGES_DIR}/${basename}-${WINDMILL_SYSTEM_TRIPLET}${WINDMILL_SYSTEM_ABI_VERSION}.tgz")
    cmake_path(REPLACE_EXTENSION PACKAGE_ARCHIVE LAST_ONLY "sha256" OUTPUT_VARIABLE PACKAGE_CHECKSUM)

    # Include package module using a function to ensure the module file will not affect variables in this scope.
    function(windmill_include_build_module package)
        cmake_parse_arguments("${CMAKE_CURRENT_FUNCTION}" "" "RESULT_VARIABLE" "" ${ARGN})
        windmill_function_refuse_arguments(${CMAKE_CURRENT_FUNCTION}_UNPARSED_ARGUMENTS)
        string(STRIP "${package}" package)
        string(STRIP "${${CMAKE_CURRENT_FUNCTION}_RESULT_VARIABLE}" ${CMAKE_CURRENT_FUNCTION}_RESULT_VARIABLE)
        windmill_function_require_arguments(package ${CMAKE_CURRENT_FUNCTION}_RESULT_VARIABLE)

        # Force the source file paths saved in the debug info to have a known (and constant) prefix. Both GDB and LLDB
        # are relatively smart to search for sources in the project root dir when an absolute path is not found so there
        # is usually no need for a custom mapping rule either manually or via .lldbinit or .gdbinit. Using the some
        # project root folder name also makes it easier. For example, on Windows, lldb should be able to auto-configure
        # a source mapping rule for a clone under D:\MyFolder\SomeProjects\Windmill as:
        #
        #      (lldb) settings show target.source-map
        #      target.source-map (path-map) =
        #      [0] "WINDMILL_SOURCE_DIR" -> "D:\MyFolder\SomeProjects"
        #
        # Useful commands in case something does not work as expected:
        #   - Check objs on macOS/Linux:
        #        $> gdb -q -ex "set height 0" -ex "info sources" -ex quit .stage/x86_64-linux-gnu/opt/debug/lib/mimalloc-secure.o
        #   - Check binaries on macOS/Linux:
        #        $> llvm-dwarfdump .stage/x86_64-linux-gnu/opt/debug/lib/luajit/libluajit-5.1.a | grep -E '_decl_file'
        #   - Check PDB source paths on Windows:
        #        $> llvm-pdbutil dump -files .stage\amd64-windows-msvc\opt\debug\lib\mimalloc-secure.pdb
        #   - Check whether a binary can locate its associated PDB (and where it is):
        #        $> dumpbin /pdbpath:verbose .stage\amd64-windows-msvc\opt\debug\lib\mimalloc-secure.dll
        #
        set(warned)
        foreach (lang IN ITEMS C CXX)
            foreach (variable IN ITEMS
                    CMAKE_${lang}_FLAGS_DEBUG
                    CMAKE_${lang}_FLAGS_RELWITHDEBINFO)
                if ("${CMAKE_${lang}_COMPILER_ID}" STREQUAL "Clang" AND "${CMAKE_${lang}_SIMULATE_ID}" STREQUAL "MSVC") # clang-cl
                    string(STRIP "${${variable}} -Xclang -fdebug-prefix-map=${WINDMILL_SOURCE_DIR}=WINDMILL_SOURCE_DIR" ${variable})
                    string(STRIP "${${variable}} -Xclang -fmacro-prefix-map=${WINDMILL_SOURCE_DIR}=WINDMILL_SOURCE_DIR" ${variable})
                elseif ("${CMAKE_${lang}_COMPILER_ID}" MATCHES "^(GNU|Clang|AppleClang)$")
                    # Specifying -ffile-prefix-map is equivalent to specifying all the individual -f*-prefix-map options.
                    string(STRIP "${${variable}} -ffile-prefix-map=${WINDMILL_SOURCE_DIR}=WINDMILL_SOURCE_DIR" ${variable})
                else ()
                    if (NOT warned)
                        message(WARNING "Could NOT set custom source path in debug info for package \"${package}\""
                                " (unsupported compiler: \"${CMAKE_${lang}_COMPILER}\") ")
                        set(warned TRUE)
                    endif ()
                endif ()
            endforeach ()
        endforeach ()
        unset(warned)
        # Force a relative PDB path in the binary and rebase relative source paths in the PDB to a known prefix.
        if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Windows")
            foreach (artifact IN ITEMS EXE SHARED MODULE)
                foreach (variable IN ITEMS CMAKE_${artifact}_LINKER_FLAGS)
                    string(STRIP "${${variable}} /PDBALTPATH:%_PDB% /PDBSOURCEPATH:WINDMILL_SOURCE_DIR" ${variable})
                endforeach ()
            endforeach ()
        endif ()
        # Define remaining variables required for the build script
        set(PACKAGE_NAME "${package}")
        # Include build script
        include(Build${package} OPTIONAL RESULT_VARIABLE included)
        set(${${CMAKE_CURRENT_FUNCTION}_RESULT_VARIABLE} "${included}" PARENT_SCOPE)
    endfunction()
    windmill_include_build_module("${package}" RESULT_VARIABLE found)
    if (NOT found)
        message(STATUS "${error_msg} (build module not found)")
        return()
    endif ()
    # Proceed only if the stage directory exists
    if (IS_DIRECTORY "${PACKAGE_OUTPUT_DIR}")
        # Create manifest file
        cmake_path(SET manifest NORMALIZE "${PACKAGE_OUTPUT_DIR}/${basename}.json")
        cmake_path(GET PACKAGE_OUTPUT_DIR PARENT_PATH PACKAGE_ROOT_DIR)
        # Create an empty manifest before the GLOB so the manifest can also appear in the list of files
        file(TOUCH "${manifest}")
        file(GLOB_RECURSE files LIST_DIRECTORIES FALSE RELATIVE "${PACKAGE_ROOT_DIR}" "${PACKAGE_OUTPUT_DIR}/*")
        list(TRANSFORM files REPLACE "(.+)" "\"\\1\"")
        list(JOIN files ", " files)
        set(json "{}")
        string(JSON json SET "${json}" "commit" "\"${PACKAGE_COMMIT}\"")
        string(JSON json SET "${json}" "path" "\"${PACKAGE_RELATIVE_PATH}\"")
        string(JSON json SET "${json}" "revision" "\"${PACKAGE_REVISION}\"")
        string(JSON json SET "${json}" "url" "\"${PACKAGE_ORIGIN}\"")
        string(JSON json SET "${json}" "files" "[${files}]")
        file(WRITE "${manifest}" "${json}")
        unset(manifest)
        unset(json)
        unset(files)
        # FIXME: We are forced to use "${CMAKE_COMMAND} -E tar czf" here because file(ARCHIVE_CREATE) does not accept a
        #        custom root directory for the archive and seems to default to PROJECT_BINARY_DIR.
        #        See https://gitlab.kitware.com/cmake/cmake/-/issues/21653
        #
        # HACK: `cmake -E tar` does not handle symlinks correctly and will produce a tarball with lots of ../.. if the
        #       path is not resolved.
        file(REAL_PATH "${PACKAGE_ROOT_DIR}" PACKAGE_ROOT_DIR)
        file(REAL_PATH "${PACKAGE_OUTPUT_DIR}" PACKAGE_OUTPUT_DIR)
        # Make sure the package archive dir exists
        cmake_path(GET PACKAGE_ARCHIVE PARENT_PATH PACKAGE_ARCHIVE_DIR)
        file(REAL_PATH "${PACKAGE_ARCHIVE_DIR}" PACKAGE_ARCHIVE_DIR)
        file(MAKE_DIRECTORY "${PACKAGE_ARCHIVE_DIR}")

        # Create tarball
        execute_process(
                COMMAND "${CMAKE_COMMAND}" -E tar czf "${PACKAGE_ARCHIVE}" "${PACKAGE_OUTPUT_DIR}"
                WORKING_DIRECTORY "${PACKAGE_ROOT_DIR}"
                COMMAND_ERROR_IS_FATAL ANY
        )
        # Create checksum file
        file(SHA256 "${PACKAGE_ARCHIVE}" checksum)
        file(WRITE "${PACKAGE_CHECKSUM}" "${checksum}")
        unset(checksum)
    endif ()
endfunction()

# Extract a package archive into the staging directory.
# This function will raise a fatal error if the required package cannot be found or if it is invalid. This is to
# prevent subsequent calls to find_package() from accidentally picking up packages installed in the system.
# Setting WINDMILL_STAGE_PACKAGES=OFF will disable staging for all packages but staging can be individually controlled
# with WINDMILL_STAGE_PACKAGE_<PackageName> and WINDMILL_HOST_STAGE_PACKAGE_<PackageName>.
#
# When the HOST flag is specified, the package name is derived from WINDMILL_HOST_SYSTEM_TRIPLET instead of
# WINDMILL_SYSTEM_TRIPLET. This function will try to build a missing or out-of-date package before staging unless
# NO_BUILD is passed. If the package is already staged and up-to-date (i.e. the manifest file in the stage directory is
# newer than the package) this function returns immediately. Passing FORCE causes the package to be unstaged and then
# staged again even if the staged files were already up-to-date.
#
# Multiple packages may be eligible for staging. In this case, the package with the latest ABI version that is less or
# equal to WINDMILL_SYSTEM_ABI_VERSION (or WINDMILL_HOST_SYSTEM_ABI_VERSION) will be selected and deployed to the staging
# folder. As a result, the staging folder may contain binaries compiled for different triplet versions. This is expected
# and based on the assumption that all target and host systems are backward compatible, that is, a binary produced for
# an older version remains usable in newer versions.
function(windmill_stage_package package)
    cmake_parse_arguments("${CMAKE_CURRENT_FUNCTION}" "HOST;FORCE;NO_BUILD;REQUIRED" "" "" ${ARGN})
    windmill_function_refuse_arguments(${CMAKE_CURRENT_FUNCTION}_UNPARSED_ARGUMENTS)
    string(STRIP "${package}" package)
    windmill_function_require_arguments(package)

    # Variable used to check if the package staging took more than a second
    string(TIMESTAMP start "%Y-%m-%dT%H:%M:%SZ" UTC)

    if (${CMAKE_CURRENT_FUNCTION}_HOST)
        set(host HOST)
        set(triplet "${WINDMILL_HOST_SYSTEM_TRIPLET}")
        set(version "${WINDMILL_HOST_SYSTEM_ABI_VERSION}")
    else ()
        set(host)
        set(triplet "${WINDMILL_SYSTEM_TRIPLET}")
        set(version "${WINDMILL_SYSTEM_ABI_VERSION}")
    endif ()

    set(error_msg "Could NOT stage package \"${package}\" for ${triplet}")

    # All package names correspond to a submodule folder under WINDMILL_PACKAGES_SOURCE_DIR that MUST BE comprised
    # only of alphanumeric lower-case characters (i.e. 0-9, a-z). This base name is also used to compose the package
    # name.
    string(TOLOWER "${package}" basename)

    # Break early if the package is not allowed to be staged. This is checked before the stage list and not after so
    # one can still override the control variable and try to stage again at any point of the configuration phase.
    if (host)
        if (DEFINED WINDMILL_HOST_STAGE_PACKAGE_${package} AND NOT WINDMILL_HOST_STAGE_PACKAGE_${package})
            return()
        endif ()
    else ()
        if (DEFINED WINDMILL_STAGE_PACKAGE_${package} AND NOT WINDMILL_STAGE_PACKAGE_${package})
            return()
        endif ()
    endif ()

    # Check if we have already tried to stage this package to avoid multiple attempts in case of stage errors.
    set(stamp "${basename}@${triplet}")
    get_property(list GLOBAL PROPERTY "WINDMILL_PACKAGES_STAGED")
    if ("${stamp}" IN_LIST list)
        return()
    endif ()
    unset(list)

    # Mark package as built.
    set_property(GLOBAL APPEND PROPERTY "WINDMILL_PACKAGES_STAGED" "${stamp}")
    unset(stamp)

    # Build package if necessary and allowed.
    if (NOT ${CMAKE_CURRENT_FUNCTION}_NO_BUILD)
        windmill_build_package("${package}" ${host})
    endif ()

    # Select a compatible package to stage
    windmill_select_package(PACKAGE_ARCHIVE "${package}" "${triplet}" "${version}")

    # Check the package exists. Some staging packages may be explicitly REQUIRED because there is no way of knowing when
    # CMake might accidentally pick another program or library with the same name installed in the system after an
    # arbitrary call to find_package().
    if (NOT PACKAGE_ARCHIVE OR NOT EXISTS "${PACKAGE_ARCHIVE}")
        set(status STATUS)
        if (${CMAKE_CURRENT_FUNCTION}_REQUIRED)
            set(status FATAL_ERROR)
        endif ()
        message(${status} "${error_msg} (pre-compiled package archive not found)")
        unset(status)
        return()
    endif ()

    # Make the configuration depend on the archive and checksum so eventual updates will trigger a reconfiguration
    # and consequently extract the new archive.
    cmake_path(REPLACE_EXTENSION PACKAGE_ARCHIVE LAST_ONLY "sha256" OUTPUT_VARIABLE PACKAGE_CHECKSUM)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
            "${PACKAGE_ARCHIVE}"
            "${PACKAGE_CHECKSUM}"
    )

    # Check the archive checksum.
    if (EXISTS "${PACKAGE_CHECKSUM}")
        file(READ "${PACKAGE_CHECKSUM}" expected)
        string(STRIP "${expected}" expected)
        string(TOLOWER "${expected}" expected)
        file(SHA256 "${PACKAGE_ARCHIVE}" checksum)
        string(TOLOWER "${checksum}" checksum)
        if (NOT "${checksum}" STREQUAL "${expected}")
            message(FATAL_ERROR "${error_msg} (found \"${PACKAGE_ARCHIVE}\" with a bad checksum \"${checksum}\", expected \"${expected}\")")
        endif ()
    else ()
        message(FATAL_ERROR "${error_msg} (found \"${PACKAGE_ARCHIVE}\" without a checksum file)")
    endif ()

    cmake_path(SET manifest NORMALIZE "${WINDMILL_STAGE_DIR}/${triplet}/${basename}.json")
    cmake_path(SET signature NORMALIZE "${WINDMILL_STAGE_DIR}/${triplet}/${basename}.sha256")

    # If the package is already staged, check if it has to unstaged first. A package will be unstaged if staging is
    # forced, if there is no stage signature or if the archive checksum does not match the stage signature.
    if (EXISTS "${manifest}")
        set(force FALSE)
        if (NOT ${CMAKE_CURRENT_FUNCTION}_FORCE)
            if (EXISTS "${signature}")
                file(READ "${signature}" expected)
                string(STRIP "${expected}" expected)
                string(TOLOWER "${expected}" expected)
                if (NOT "${checksum}" STREQUAL "${expected}")
                    set(force TRUE)
                endif ()
            else ()
                set(force TRUE)
            endif ()
        endif ()
        if (force)
            windmill_unstage_package("${package}" ${host})
        endif ()
        unset(force)
    endif ()

    # If the package is still staged, there is nothing else to be done.
    if (EXISTS "${manifest}")
        return()
    endif ()

    file(ARCHIVE_EXTRACT
            INPUT "${PACKAGE_ARCHIVE}"
            DESTINATION "${WINDMILL_STAGE_DIR}"
            PATTERNS "${triplet}"
            TOUCH
    )

    # Read the new manifest to report
    file(READ "${manifest}" json)
    string(JSON revision GET "${json}" "revision")
    string(JSON url GET "${json}" "url")

    # As of CMake 3.22 the implementation of find_library caches the list of files of the directories searched. The
    # cache uses the modified time of the directory to determine when a refresh is needed but the granularity of the
    # modified time stored by CMake is seconds (posix time).
    # See https://github.com/Kitware/CMake/blob/31f835410efeea50acd43512eb9e5646a26ea177/Source/cmGlobalGenerator.cxx#L3125
    # This results in a bad interaction between windmill_stage_package and find_library inside find modules because
    # once a call to find_library is made further calls will not see eventual new files extracted by
    # windmill_stage_package unless at least one second has elapsed. For example, assuming the stage directory is
    # empty, consider a package A that depends on B and C. Then a call to find_package(A) would result in successive
    # calls like these:
    #
    #    -- FindA.cmake
    #    windmill_stage_package(A),
    #    find_library(A),
    #    -- FindB.cmake
    #    windmill_stage_package(B),
    #    find_library(B),
    #    -- FindC.cmake
    #    windmill_stage_package(C),
    #    find_library(C)
    #
    # Now if each find module does not take a second or more the windmill_stage_package() call of the next will set the
    # timestamp of the lib directory to the same value and the following call to find_library will not see the new files
    # because it will rely on the cache taken by the previous find_library call that is still valid and only contains
    # files staged for A (or A and B depending on when the clock's second flipped)
    #
    # Unfortunately, the only way to ensure a call to windmill_stage_package will always be able to update the modified
    # time of an eventual library directory to a different timestamp than the one cached by a previous call to
    # find_library is to impose a minimum delay of 1 second and only then change the library directories timestamp.
    #
    # At least we check if it took more than 1 second to get here (or there was at least a 1-second flip) so there is no
    # need for a delay.
    string(TIMESTAMP now "%Y-%m-%dT%H:%M:%SZ" UTC)
    if ("${now}" STREQUAL "${start}")
        execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 1)
    endif ()

    # Ensure library folders have a current local timestamp to make sure find_library will see the latest files
    foreach (config IN LISTS CMAKE_CONFIGURATION_TYPES)
        set(folder "lib")
        if (NOT "${config}" STREQUAL "Release")
            string(TOLOWER "opt/${config}/lib" folder)
        endif ()
        file(TOUCH_NOCREATE "${WINDMILL_STAGE_DIR}/${triplet}/${folder}")
        unset(folder)
    endforeach ()

    # Ensure the manifest has a current local timestamp instead of that from the archive. This is important to determine
    # when an archive has been updated in relation to what we have in the stage.
    file(TOUCH_NOCREATE "${manifest}")

    # Write staged package checksum
    file(WRITE "${signature}" "${checksum}")

    message(STATUS "Staged ${package}: ${PACKAGE_ARCHIVE} (revision: \"${revision}\", origin: \"${url}\")")
endfunction()

# Remove a package from the staging directory, if staged. Otherwise, this function has no effect.
function(windmill_unstage_package package)
    cmake_parse_arguments("${CMAKE_CURRENT_FUNCTION}" "HOST" "" "" ${ARGN})
    windmill_function_refuse_arguments(${CMAKE_CURRENT_FUNCTION}_UNPARSED_ARGUMENTS)
    string(STRIP "${package}" package)
    windmill_function_require_arguments(package)

    if (${CMAKE_CURRENT_FUNCTION}_HOST)
        set(triplet "${WINDMILL_HOST_SYSTEM_TRIPLET}")
    else ()
        set(triplet "${WINDMILL_SYSTEM_TRIPLET}")
    endif ()

    # All package names correspond to a submodule folder under WINDMILL_PACKAGES_SOURCE_DIR that MUST BE comprised
    # only of alphanumeric lower-case characters (i.e. 0-9, a-z). This base name is also used to compose the package
    # name.
    string(TOLOWER "${package}" ${basename})

    cmake_path(SET manifest NORMALIZE "${WINDMILL_STAGE_DIR}/${triplet}/${basename}.json")
    cmake_path(SET signature NORMALIZE "${WINDMILL_STAGE_DIR}/${triplet}/${basename}.sha256")

    # If the package is already unstaged there is nothing else to be done.
    if (NOT EXISTS "${manifest}")
        return()
    endif ()

    # Read list of staged files from the manifest
    set(staged)
    file(READ "${manifest}" json)
    string(JSON last LENGTH "${json}" "files")
    math(EXPR last "${last} - 1")
    foreach (index RANGE ${last})
        string(JSON filepath GET "${json}" "files" "${index}")
        cmake_path(APPEND WINDMILL_STAGE_DIR "${filepath}" OUTPUT_VARIABLE filepath)
        list(APPEND staged "${filepath}")
    endforeach ()
    # Remove staged files
    if (staged)
        file(REMOVE ${staged})
    endif ()
    # Make sure manifest and signature are removed (in case they did not appear in the manifest file list).
    file(REMOVE "${manifest}")
    file(REMOVE "${signature}")
endfunction()

# A wrapper over find_library() to be used in custom FindModules. It will look for a library for each of the specified
# configurations following project packaging conventions. Release libraries are expected to be located under a "lib"
# subdirectory while other configurations should be located under "opt/<config>/lib".
function(windmill_find_library prefix)
    cmake_parse_arguments("${CMAKE_CURRENT_FUNCTION}" "" "" "CONFIGURATIONS;NAMES;PATHS;PATH_SUFFIXES;VARIANTS" ${ARGN})
    windmill_function_refuse_arguments(${CMAKE_CURRENT_FUNCTION}_UNPARSED_ARGUMENTS)
    foreach (argument IN ITEMS
            CONFIGURATIONS
            NAMES)
        if (DEFINED ${argument})
            string(STRIP "${${CMAKE_CURRENT_FUNCTION}_${argument}}" ${CMAKE_CURRENT_FUNCTION}_${argument})
        endif ()
    endforeach ()
    windmill_function_require_arguments(prefix ${CMAKE_CURRENT_FUNCTION}_CONFIGURATIONS ${CMAKE_CURRENT_FUNCTION}_NAMES)

    # Find a library for each config and create a CACHE variable for it
    foreach (config IN LISTS ${CMAKE_CURRENT_FUNCTION}_CONFIGURATIONS)
        set(libdir "lib")
        if (NOT "${config}" STREQUAL "Release")
            set(libdir "opt/${config}/lib")
        endif ()
        string(TOUPPER "${config}" config)
        set(path_suffixes "${${CMAKE_CURRENT_FUNCTION}_PATH_SUFFIXES}")
        list(TRANSFORM path_suffixes PREPEND "${libdir}/")
        list(PREPEND path_suffixes "${libdir}")
        unset(libdir)
        find_library(${prefix}_LIBRARY_${config}
                NAMES ${${CMAKE_CURRENT_FUNCTION}_NAMES}
                NAMES_PER_DIR
                PATHS ${${CMAKE_CURRENT_FUNCTION}_PATHS}
                PATH_SUFFIXES ${path_suffixes}
                ONLY_CMAKE_FIND_ROOT_PATH
        )
        mark_as_advanced(${prefix}_LIBRARY_${config})
        foreach (variant IN LISTS ${CMAKE_CURRENT_FUNCTION}_VARIANTS)
            set(variant_path_suffixes "${path_suffixes}")
            list(TRANSFORM variant_path_suffixes APPEND "/${variant}")
            string(TOUPPER "${variant}" variant)
            find_library(${prefix}_${variant}_LIBRARY_${config}
                    NAMES ${${CMAKE_CURRENT_FUNCTION}_NAMES}
                    NAMES_PER_DIR
                    PATHS ${${CMAKE_CURRENT_FUNCTION}_PATHS}
                    PATH_SUFFIXES ${variant_path_suffixes}
                    ONLY_CMAKE_FIND_ROOT_PATH
            )
            unset(variant_path_suffixes)
            mark_as_advanced(${prefix}_${variant}_LIBRARY_${config})
        endforeach ()
        unset(path_suffixes)
    endforeach ()
endfunction()

# CMake builds Linux and macOS binaries with rpath so programs can be executed from the output dir without a custom
# LD_LIBRARY_PATH env var. On Windows, this is not possible but we can use TARGET_RUNTIME_DLLS to copy runtime
# dependencies to the output dir as a POST BUILD step. Debug DLLs must also be accompanied by their PDBs.
# Note that contrary to CMake documentation, the TARGET_RUNTIME_DLLS generator expression does not copy MODULE
# dependencies.
# See https://gitlab.kitware.com/cmake/cmake/-/merge_requests/7186
# See https://gitlab.kitware.com/cmake/cmake/-/issues/22993
# Also note that $<TARGET_RUNTIME_DLLS> expands to an empty string when there are no DLL dependencies.
# See https://gitlab.kitware.com/cmake/cmake/-/issues/23543
# See https://gitlab.kitware.com/cmake/cmake/-/merge_requests/7913
function(windmill_copy_runtime_dependencies_after_build target)
    if (WIN32)
        # It's more convenient to use a utility script in the project root dir than `cmake -E copy` because there is
        # no way to convert TARGET_RUNTIME_DLLS to a list of PDBs using generator expressions and there is no pactical
        # way to ignore missing PDBs either.
        add_custom_command(TARGET "${target}" POST_BUILD
                COMMAND "${WINDMILL_COMMAND_DLLCOPY}"
                "$<TARGET_FILE_DIR:${target}>"
                "$<TARGET_RUNTIME_DLLS:${target}>"
                COMMENT "Copying runtime dependencies to output directory"
                COMMAND_EXPAND_LISTS
                JOB_POOL console
        )
    endif ()
endfunction()
