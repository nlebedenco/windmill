![Windmill Logo](windmill-logo.jpg "Windmill")

# Windmill

This is a template for multi-platform projects designed around at least one
Zephyr application and one or more applications for non-embedded platforms
(e.g. servers, desktop clients, mobile frontends, etc.).

Target systems currently supported include Windows, Linux, Android and Zephyr.

Work is in progress to support Darwin (macOS), iOS, tvOS, watchOS and visionOS.

Main features include:

- A nice top-level CMakeLists.txt so we can configure and build Zephyr and
  non-Zephyr applications alike from the command-line or within an IDE without
  the need for custom batch scripts and workarounds;

- Ability to use CMake presets to define target system constraints;

- Target system and compiler detection based on CMake toolchain files;

- Automatic set up of Python environment and West workspace;

- A bare-bones Zephyr module named `windmill` located under `firmware/zephyr`
  that is automatically imported and provides an entry point for custom boards,
  drivers, libraries and even other modules (based on Zephyr's
  example-application);

- Preserved compatibility with West for Zephyr applications;

- Integration of clang-tidy, include-what-you-use and cppcheck with Zephyr and
  non-Zephyr builds alike without the need to install and configure CodeChecker.
  Only files used in the build are checked, NOT the entire code base so checks
  can be incorporated in the normal development workflow;

- Ability to build external dependencies not tied to Zephyr on demand, store
  pre-compiled packages and stage binaries as necessary for the build (currently
  builds include-what-you-use and a relocatable version of cppcheck);

- Pre-commit hooks to enforce code format and git commit message conventions at
  the working copies.

In addition, this is a fork-friendly repository in which all branches are
prefixed with `windmill/` including the default branch (`windmill/master`) so
users can fork and expand on it without any extra set up and without unexpected
conflicts between upstream and their own branches. In fact, this same branch
naming convention can be adopted by new forks. For example, users can also
define their own prefixes, should their forks be re-used by others as a
template, as opposed to being a final top-level CMake project in itself.

## Prior knowledge

Before using this project template make sure you understand the basic concepts
behind CMake and how projects are usually organized. Refer to
[Getting Started with CMake](https://cmake.org/getting-started/) for more
information.

## Third-Party Software

Third-party source code used either in full or in part is described in
[OTHERS](OTHERS.md).

## Host requirements

Supported host systems:

| Host         | Version | SDK                  |
|--------------|---------|----------------------|
| Windows      | 10.x    | Win SDK 10.0.20348.0 |
| Ubuntu Linux | 24.04   | Glibc 2.39           |
| macOS        | 12.x    | macOS SDK 12         |

The following dependencies must be installed in all host systems:

| Tool   | Version        |
|--------|----------------|
| CMake  | \>=3.25        |
| Python | \>=3.9...<3.12 |
| Ninja  | \>=1.12        |

The following IDEs are supported in all host systems:

| IDE    | Version   |
|--------|-----------|
| CLion  | \>=2024.1 |
| VSCcde | \>=1.87   |

## Quick start

There are no shortcuts. Read this file until the end.

Seriously, you should read this file until the end and also the opening comments
in the top-level [CMakeLists.txt](CMakeLists.txt) if you want to use this
project template effectively.

If you cannot wait to build something try this:

1. Make sure you have Git, CMake >= 3.25, Python >= 3.9 (< 3.12) and
   Ninja >= 1.12. If you don't know what I'm talking about stop now, take a deep
   breath and continue in the next session:
   [How to set up your host system](#how-to-set-up-your-host-system)

2. Download
   the [Zephyr SDK bundle archive](https://docs.zephyrproject.org/latest/develop/toolchains/zephyr_sdk.html#zephyr-sdk-installation)

3. Unpack as instructed by the Zephyr SDK web page but DO NOT run the setup
   script. It offers zero value because:

    1. If you downloaded the bundle archive you do not need to download any arch
       toolchain separately;

    2. Host tools are only supported in Linux, and downloading tools is nothing
       you cannot do later yourself, once you know what you are doing;

    3. It will register the cmake modules of the Zephyr SDK downloaded in your
       host's CMake registry, but this is only to be able to find the location
       where the SDK was extracted which may be a source of confusion later when
       you forget about the CMake registry and try to use a different SDK you
       just downloaded and extracted somewhere else. The CMake registry is meant
       for you to be able to find a package using `find_package` in your CMake
       script but Zephyr scripts are capable of finding the SDK using a simple
       environment variable which is much simpler to reason about, verify and
       change when necessary. Don't mess with your CMake registry if you do not
       really need to. You're welcome.

4. Set up your `ZEPHYR_SDK_INSTALL_DIR` environment variable to point to the
   base of your Zephy-SDK installation so that different Zephyr SDK toolchains
   can be selected as needed by Zephyr's CMake scripts. For example, if you
   downloaded `zephyr-sdk-0.16.5_windows-x86_64.7z` and extracted it under
   `C:\Portable\Zephyr` then use `ZEPHYR_SDK_INSTALL_DIR=C:\Portable\Zephyr`.
   Zephyr will by default choose the most recent SDK supported by its revision
   so multiple SDK versions can coexist under the same base folder.

5. Open a terminal window

6. Clone `windmill`

    1. `$ git clone git@github.com:nlebedenco/windmill.git`

    2. `$ cd windmill`

7. List the presets you can build on your host system:

    1. `$ cmake --list-presets`

8. Configure `custom_plank/hello_world` using:

    1. `$ cmake --preset=custom_plank/hello_world`

9. Build the `custom_plank/hello_world` preset you just configured using:

    1. `$ cmake --build .build/preset/custom_plank/hello_world`

Congratulations, you just built a firmware that barely does anything for the
`custom_plank` example board. Feeling accomplished? Great! Now, read this file
until the end.

## How to set up your host system

### Windows setup (Windows 10.x)

1. Update Windows:
    1. Select `Start->Settings->Update & Security->Windows Update`
    2. Click *Check for updates and install any that are available*

2. Install Visual Studio 2022 Update 17.9.5 or higher

    1. Make sure you have selected:
        - C++ 2022 Redistributable Update
        - C++ Clang compiler for Windows
        - MSBuild support for LLVM (clang-cl) toolset
        - MSVC v143 - VS 2022 C++ x64/x86 build tools (v14.38-17.8)
          The version should match the redistributable used by your Windows
          host. Do not trust only *latest* because sometimes VS updates are
          shipped with a CRT version that is not available yet in a
          redistributable package but the build system needs the guarantee that
          binaries built for the host system can run (this is actively checked
          in the configuration phase).
        - C++ core features
        - C++ v14.38 (17.8) ATL for v143 build tools (x86 & x64)
          This version should match the one used for VS 2022 C++ x64/x86 build
          tools.
        - C++ v14.38 (17.8) MFC for v143 build tools (x86 & x64)
          This version should match the one used for VS 2022 C++ x64/x86 build
          tools.
        - Windows 10 SDK (10.0.20348.0)
        - Windows Universal C Runtime

3. Install [Chocolatey](https://chocolatey.org/install)

4. Open a cmd.exe terminal as **Administrator**. To do so, press the
   Windows key, type `cmd`, right-click on *Command Prompt* in the search
   results, and choose *Run as Administrator*.

5. Disable global confirmation in Chocolatey to avoid having to confirm the
   installation of individual programs:
   ```
   $ choco feature enable -n allowGlobalConfirmation
   ```

6. Install basic tools
   ```
   $ choco install cmake ninja python
   ```
   You may want to skip installing a tool if you already have it installed as
   part of another software package. For example, JetBrains CLion comes bundled
   with fairly recent versions of CMake and Ninja. Only ensure that the
   executables can be found in the system path.

7. Download and unpack the
   latest [Zephyr SDK bundle archive](https://docs.zephyrproject.org/latest/develop/toolchains/zephyr_sdk.html#zephyr-sdk-installation)
   for Windows under `C:\Portable\Zephyr`

8. DO NOT run the Zephyr-SDK setup script. Reasons for it in
   [Quick start](#quick-start) step 3.

9. Configure environment variables:

    1. In the Windows Start Menu open `Settings`

    2. Click in `About->Advanced System Settings->Environment Variables`

    3. Under *System variables* add these:
       ```
       CMAKE_GENERATOR=Ninja Multi-Config
       ZEPHYR_SDK_INSTALL_DIR=C:\Portable\Zephyr"
       ```

10. Follow [this git how-to](documents/git/git.md) for instructions on how to
    set up Git if you have not yet done so.

### WSL2 setup (Ubuntu 24.04)

WSL2 is only meant to build Linux native apps. Zephyr applications CANNOT be
built using WSL. Use the Windows host system instead.

The configuration process is very similar to the one used for Linux native hosts
except that we have to ensure that the Git client used in WSL2 is the Windows
native client in order to avoid problems with auto CRLF and the Git index
becoming unexpectedly "dirty".

1. Install WSL2 and Ubuntu 24.04 if you have not already done so.
   See [Install Ubuntu on WSL2](https://canonical-ubuntu-wsl.readthedocs-hosted.com/en/latest/guides/install-ubuntu-wsl2/)
   for directions.

2. Open a WSL2 terminal

3. Update the system
   ```
   $ sudo apt update
   $ sudo apt upgrade
   ```

4. Edit (or create) the file `/etc/wsl.conf` and add the section:
   ```
   [interop]
   appendWindowsPath=false
   ```
   This is necessary because by default, WSL2 appends the Windows PATH
   environment variable into its own to allow to users to execute Windows
   programs from within WSL (yikes!). This may cause problems with tools that
   search the system such as npm and cmake as discussed
   [here](https://mauridb.medium.com/wsl2-windows-python-and-node-resolving-some-conflicts-8a329fddc3a5).

5. Install development depedencies:
   ```
   $ sudo apt install \
     build-essential gdb gperf ninja-build \
     clang clang-tidy clang-format lldb lld llvm \
     python-is-python3 python3-pip python3-setuptools python3-venv \
     pkg-config perl doxygen graphviz valgrind cmake
   ```

6. Edit `/etc/profile` and append the following lines:
   ```
   export CMAKE_GENERATOR="Ninja Multi-Config"
   ```

7. Remove Git if installed
   ```
   $ sudo apt remove git
   $ sudo apt autoremove
   ```

8. Remove any .gitconfig from your WSL $HOME dir
    ```
    $ rm ~/.gitconfig
    ```

9. Create a symlink to the Windows Git executable (actual location of
   git.exe may vary)
    ```
    $ sudo mkdir -p /usr/local/bin
    $ sudo ln -s "/mnt/c/Program Files/Git/bin/git.exe" /usr/local/bin/git
    ```

   Optionally you might want to ensure any configured tool in your
   `.gitconfig` is accesible in WSL2 too. For example, if your gitconfig
   uses notepad++ for the editor and Araxis for diff/merge you could do:

    ```
    $ sudo ln -s "/mnt/c/ProgramData/chocolatey/bin/notepad++.exe" /usr/local/bin/notepad++
    $ sudo ln -s "/mnt/c/Program Files/Araxis/Araxis Merge/compare.exe" /usr/local/bin/compare
    ```

   It is not enough to create the symlinks in `~/.local/bin` because CLion
   runs WSL profiles with `wsl --exec /bin/bash -c` in which case the `PATH`
   variable will not include `$HOME/.local/bin`

10. Restart the terminal session

11. Print your version of glibc
    ```
    $ ldd --version
    ```

12. Print which libstdc++ is installed
    ```
    $ /sbin/ldconfig -p | grep stdc++
    ```

13. List all compatible versions of libstdc++ (version 3.4.0 and above)
    ```
    $ strings /lib/x86_64-linux-gnu/libstdc++.so.6 | grep LIBCXX
    ```

### Linux setup

#### Ubuntu 22.04

1. Open a terminal window

2. Update the system
   ```
   $ sudo apt update
   $ sudo apt upgrade
   ```

3. Install development depedencies:
   ```
   $ sudo apt install \
     build-essential gdb gperf ninja-build \
     clang clang-tidy clang-format lldb lld llvm \
     clang-15 clang-tidy-15 clang-format-15 llbb-15 llvm-15
     python-is-python3 python3-pip python3-setuptools python3-venv \
     pkg-config perl doxygen graphviz valgrind
   ```

4. Download and
   run [update-alternatives-clang.sh](https://raw.githubusercontent.com/nlebedenco/windmill/windmill/master/extras/ubuntu/update-alternatives-clang.sh)
   This is a shell script that will configure the Linux host to use clang 15 by
   default instead of 14. Run as:
   ```
   $ sudo ./update-alternatives-clang.sh 15 10
   ```

5. Uninstall the distribution default CMake package if it was previously
   installed:
   ```
   $ sudo apt-get remove cmake
   $ sudo apt autoremove
   ```

6. Install CMake 3.27 using snap:
   ```
   $ sudo snap install cmake --classic --channel=3.27/stable
   ```

7. Download and unpack the
   latest [Zephyr SDK bundle archive](https://docs.zephyrproject.org/latest/develop/toolchains/zephyr_sdk.html#zephyr-sdk-installation)
   for Linux under `/opt/zephyr`

8. DO NOT run the Zephyr-SDK setup script. Reasons for it in
   [Quick start](#quick-start) step 3.

9. Edit `/etc/profile` and append the following lines:
   ```
   export CMAKE_GENERATOR="Ninja Multi-Config"
   export ZEPHYR_SDK_INSTALL_DIR="/opt/zephyr"
   ```

10. Follow [this git how-to](documents/git/git.md) for instructions on how to
    set up Git if you have not yet done so.

11. Print your version of glibc
    ```
    $ ldd --version
    ```

12. Print which libstdc++ is installed
    ```
    $ /sbin/ldconfig -p | grep stdc++
    ```

13. List all compatible versions of libstdc++ (version 3.4.0 and above)
    ```
    $ strings /lib/x86_64-linux-gnu/libstdc++.so.6 | grep LIBCXX
    ```

#### Ubuntu 24.04

This is simpler than in Ubuntu 22.04 because Clang and CMake are already updated
in this release.

1. Open a terminal window

2. Update the system
   ```
   $ sudo apt update
   $ sudo apt upgrade
   ```

3. Install development depedencies:
   ```
   $ sudo apt install \
     build-essential gdb gperf ninja-build \
     clang clang-tidy clang-format lldb lld llvm \
     python-is-python3 python3-pip python3-setuptools python3-venv \
     pkg-config perl doxygen graphviz valgrind cmake
   ```

4. Download and unpack the
   latest [Zephyr SDK bundle archive](https://docs.zephyrproject.org/latest/develop/toolchains/zephyr_sdk.html#zephyr-sdk-installation)
   for Linux under `/opt/zephyr`

5. DO NOT run the Zephyr-SDK setup script. Reasons for it in
   [Quick start](#quick-start) step 3.

6. Edit `/etc/profile` and append the following lines:
   ```
   export CMAKE_GENERATOR="Ninja Multi-Config"
   export ZEPHYR_SDK_INSTALL_DIR="/opt/zephyr"
   ```

7. Follow [this git how-to](documents/git/git.md) for instructions on how to
   set up Git if you have not yet done so.

8. Print your version of glibc
    ```
    $ ldd --version
    ```

9. Print which libstdc++ is installed
    ```
    $ /sbin/ldconfig -p | grep stdc++
    ```

10. List all compatible versions of libstdc++ (version 3.4.0 and above)
    ```
    $ strings /lib/x86_64-linux-gnu/libstdc++.so.6 | grep LIBCXX
    ```

### macOS setup

TODO

## How to set up your IDE

### CLion

- Supported version: \>= 2024.1

- Suggested IDE settings:

  TODO

- Project settings:

    Some of these settings are stored in the XML files tracked in the `.idea`
    folder and thus will already be set for you when you open the project.

    - Appearance & Behaviour::Scopes
        - Authored
            - Pattern:
              ```
              (file:.clang-format
               file:.clang-tidy
               file:.editorconfig
               file:*.md
               file:*.json
               file:*.yaml
               file:*.yml
               file:*.xml
               file:*.txt
               file:*.cmake
               file:*.lua
               file:*.rc
               file:*.c
               file:*.cc
               file:*.cpp
               file:*.cxx
               file:*.h
               file:*.hpp
               file:*.hxx
               file:*.py
               file:*.in
               file:*.conf
               file:defconfig
               file:Kconfig
               file:Kconfig.*)&&!file:.*//*&&!file:submodules/*//*&&!file:packages//*
              ```
        - CMake
            - Pattern:
              ```
              (file:*.cmake
               file:*.txt)&&!file:.*//*&&!file:submodules/*//*&&!file:packages//*
              ```
        - Copyrighted
            - Pattern:
              ```
              (file:*.lua
               file:*.rc
               file:*.c
               file:*.cc
               file:*.cpp
               file:*.cxx
               file:*.h
               file:*.hpp
               file:*.hxx
               file:*.py)&&!file:.*//*&&!file:submodules/*//*&&!file:packages//*
              ```
        - Kconfig
            - Pattern:
              ```
              (file:*.conf
               file:defconfig
               file:Kconfig
               file:Kconfig.*)&&!file:.*//*&&!file:submodules/*//*&&!file:packages//*
              ```
        - Python
            - Pattern:
              ```
              file:*.py&&!file:.*//*&&!file:submodules/*//*&&!file:packages//*
              ```
        - Templates
            - Pattern:
              ```
              file:*.in&&!file:.*//*&&!file:submodules/*//*&&!file:packages//*
              ```
    - Editor::Code Style
        - Scheme: Project
            - General
                - Line separator: `System-Dependent` (overriden by
                  .editorconfig)
                - Hard wrap at: 0
                - Visual guides: 0
                - Enable ClangFormat (only for C/C++/Objective-C): True
            - Formatter
                - Do not
                  format: `*.rc;.*/*;.*/**/*;submodules/*;submodules/**/*`
                - Turn formatter on/off
                    - Off: `(clang-format|cmake-format\:) off`
                    - On: `(clang-format|cmake-format\:) on`
                    - Enable regular expressions in formatter markers: True
            - C/C++
                - C++
                    - Insert "virtual" attribute together with "overide": True
                - Code Generation
                    - Documentation Comments
                        - Tag prefix in line comments: `@param`
                        - Tag prefix in block comments: `@param`
    - Build, Execution, Deployment
        - Toolchains (these are system-wise settings, so they need to be
          configured only once, and can be reused across multiple projects based
          on Windmill).
            - Add new toolchain based on the *System* profile.
                - Name: `Zephyr Windmill `
                - CMake: `Bundled`
                - Build tool: `<empty>`
                - C compiler: `<empty>`
                - C++ compiler: `<empty>`
                - Debugger: `Bundled GDB`
            - Add new toolchain based on the *System* profile.
                - Name: `Android Windmill `
                - CMake: `Bundled`
                - Build tool: `<empty>`
                - C compiler: `<empty>`
                - C++ compiler: `<empty>`
                - Debugger: `Bundled GDB`
        - CMake
            - Profiles are automatically generated by CLion following the
              contents of [CMakePresets.json](CMakePresets.json).
            - You may copy and/or enable profiles as desired.

### VSCode

TODO

## How to build

TODO: Document build types

TODO: Document that CMAKE_C_FLAGS and CMAKE_CXX_FLAGS are ignored in Zephyr
builds

1. Open a terminal window

2. Clone the repository and change into the project root directory
   ```
   $ git clone --recurse-submodules git@github.com:nlebedenco/windmill
   $ cd windmill
   ```

### Using CMake

1. You can list all configuration presets supported by the host system with:
   ```
   $ cmake --list-presets
   ```

2. Configure the project using a preset
   ```
   $ cmake --preset x86_64-pc-windows-msvc
   ```
   Presets are divided into desktop, mobile and zephyr. Desktop presets are
   named after canonical triplets for *PC* and *Apple* platforms. Firmware
   presets are named after the concatenation of board name and application name.

   Note that sources under the [platforms](platforms) folder can only be built
   for desktop or mobile systems and thus require a corresponding.

   Conversely sources under `.extrenal/zephyr` and `firmware/zephyr` folders can
   only be built for *zephyr* and thus require a firmware preset.

   Desktop and mobile applications support both single and multi-config
   generators. By default, they will use `Ninja Multi-Config`.

   Firmware applications however only support `Ninja` and `Makefile` generators
   in their single-config variants due to limitations of the Zephyr project
   upstream so firmware presets will use `Ninja` by default.

   Remember that when using CMake with a single-config generator (always the
   case for firmware configurations) a custom build type, if desired, must be
   passed in the command line using `-DCMAKE_BUILD_TYPE=` and cannot be changed
   later by the build command.

   For example:
   ```
   $ cmake --preset nucleo_u575zi_q-empty -DCMAKE_BUILD_TYPE=Release
   ```
   On the other hand, when using a multi-config (as available for desktop
   applications only) CMake will ignore `CMAKE_BUILD_TYPE` and a custom build
   type, if desired, can be specified later in the build command line using the
   `--config` argument.

   Supported build types are: Debug, Release, RelWithDebInfo, MinSizeRel.
   If omitted, the default build type is Debug.

   For more information
   see [CMake command line documentation](https://cmake.org/cmake/help/v3.25/manual/cmake.1.html#generate-a-project-buildsystem).

   You might also want to pass `-DCMAKE_EXECUTE_PROCESS_COMMAND_ECHO=STDOUT`
   for verbose output of commands executed in the configuration phase and
   `-DCMAKE_VERBOSE_MAKEFILE=ON` for verbose output of commands executed in the
   build phase.

3. Build the project
   ```
   $ cmake --build .build/preset/x86_64-pc-windows-msvc`
   ```
   For more information
   see [CMake command line documentation](https://cmake.org/cmake/help/v3.25/manual/cmake.1.html#build-a-project).

### Using West

The recommended build method is using CMake and presets but as explained above
but West is still used internally to configure Zephyr, so it remains possible to
build Zephyr applications (internal or external) to the template project using
West.

DO NOT try to build non-Zephyr applications with West. It was simply not
designed for that. It might work for trivial cases, but you will at best just
end up with a convoluted and obfuscated command line.

1. Configure a convenient default binary directory
   ```
   west config build.dir-fmt .build/west/{board}-{app}
   ```

2. Configure and build

    1. Desktop or firmware project using a preset
       ```
       $ west build -b x86_64-pc-windows-msvc -- --preset x86_64-pc-windows-msvc
       ```
       Note that West invokes CMake using its own generator settings which
       by default is Ninja (single-config). This cannot be changed using build
       command line arguments but may be changed in the west config file or
       using
       the `west config` command. Any generator specified in the preset is
       ignored as well as the `CMAKE_GENERATOR` environment variable.

       Similarly, West explicitly sets a build directory based on its own
       configuration. Any binary directory specified in the preset is also
       ignored.

    2. Firmware project without a preset
       ```
       $ west build -b nucleo_u575zi_q firmware/zephyr/apps/empty
       ```

    3. Zephyr sample without a preset
       ```
       $ west build -b nucleo_u575zi_q .external/zephyr/samples/hello_world
       ```

## How to customize CMake presets

TODO: Describe the use of presets and how fork presets can be included in
CMakePresets.json. Unwanted windmill presets can be hidden using a
CMakeUserPresets.json or removed altogether in forks.

## How to add new Zephyr modules

TODO: Document addition of new remote modules in a fork using submanifests
and how to properly have your own forks overriding zephyr modules
(must disable auto import of modules using `import: false` in each
zephyr project listed in the manifest) - Example in 100-windmill.yml

TODO: Document addition of new local modules in a fork under the
firmware/zephyr/modules folder

## Version scheme

Current version is set in [VERSION](VERSION) according to
[semantic versioning 2.0.0](http://semver.org) but limited to
`<MAJOR>.<MINOR>.<PATCH>[-<PRE>]` where [PRE] is the pre-release version
component which must be numeric only. This implies [-PRE] only makes sense when
[PATCH] is zero.

This file is consumed by [shared.cmake](cmake/shared.cmake) which in turn
propagates
the information to all build targets through an auto-generated config header.
Check [config header template](cmake/templates/config.h.in) for more
information.

We do not simply rely on Git tags because:

1. Git tags can be easily deleted or changed by mistake, in particular by
   inexperienced developers;

2. Git tags are discarded when the repository is archived or project files are
   copied without the `.git` folder.

3. Git tags may have all sorts of arbitrary formats

4. It is relatively easy to design a git-hook that automatically tags the
   repository with the contents of the VERSION file whenever it gets modified.
   This is not implemented because the tag format and conditions may vary
   according to the project. Special consideration must be given to whether a
   tag would be allowed to move should two branches end up having VERSION files
   with the same value or if only a specific branch (e.g. main) should receive
   version tags and what to with the tag when the branch HEAD moves.

It does not mean users should avoid Git tags. Only that Git tags should not be
used as the primary source of truth for project version.

CMake predates semantic versioning and thus for historical reasons it supports
version numbers defined as `<MAJOR>[.<MINOR>[.<PATCH>[.<TWEAK>]]]`. Note that
if `<TWEAK>` is omitted, CMake's version format is reduced to
[semantic versioning 1.0](https://semver.org/spec/v1.0.0.html).

For practical purposes and to reduce potential points of failure, projects
should refrain from using the `<TWEAK>` version component.

Mind that version numbers with pre-release or build components must be sanitized
before use in CMake scripts, or they will not behave as expected (e.g. will not
be correctly compared).

The recommended practice is to use the pre-release component inside the
[VERSION](VERSION) file only while the branch is in a development stage. Once it
is considered stable, a release branch should be created where the pre-release
component is removed from the project version and from that point on, any update
increases the patch version component.

## Repository Rules

- File/Folder names MUST be considered case-sensitive regardless of the host
  operating system in use.

- DO NOT commit symlinks.

- Text files should use LN as default EOL save for specifc cases (e.g. special
  Windows files such as *.cmd) known to require CRLF. These exceptions can be
  handled (and tracked) in [.gitattributes](.gitattributes)

- Submodule references SHOULD use SSH links, not HTTPS.
    - DO NOT

      `git submodule add https://github.com:nlebedenco/llvm-project.git`

    - DO

      `git submodule add git@github.com:nlebedenco/llvm-project.git`

- Text files SHOULD NOT use TAB characters **unless otherwise noted by a
  specific coding style**.

    - The large majority of modern text editors already support automatic
      insertion of spaces when the user types in a TAB so there is no extra
      typing required;

    - The resulting relative alignment of text rendered using a monospace font
      is only predictable with spaces. It is true that most text editors can
      also reder a TAB using a configurable number of space characters, so many
      developers see that as an opportunity to provide user-configurable
      indentation for free and cater to all audiences regardless of the editor
      used. After all, indentation only exists to improve readability which in
      turn is a very subjective topic. The problem is that relative alignment is
      only preserved across editors for TABs used in the beginning of a line. If
      there is any other character before the TAB(s), even a white space,
      different editors may disagree in how to render the TAB(s) and produce
      different relative alignment despite the use of a monospace font.
      Basically, a text editor may choose to render a TAB in two ways: 1) direct
      replacement, where each TAB is blindly replaced with the configured amount
      of white space characters; 2) snap-in replacement (sometimes referred to
      as *smart indentation*), where each TAB is replaced only by the necessary
      number of white-space characters to have the cursor at a position that is
      a multiple of the configured amount of white space characters per TAB. An
      editor may choose to implement one, the other or even a mix of both
      methods by conditionally switching. This means that the relative alignment
      of text produced with TABs (which includes but is not limited to
      indentation) becomes editor-dependent. For example, consider the following
      input text using TABs indicated by a `\t` for clarity:
      ```
      \t.\t.\t.\t.\t.\t.\t.\t.\t.\t.
      \tThe quick\tbrown\t\t\t\tfox
      \t\tjumps\tover the\tlazy\tdog
      ```
      When `1 TAB = 4 spaces`, snap-in replacement produces:
      ```
          .   .   .   .   .   .   .   .   .   .
          The quick   brown               fox
              jumps   over the    lazy    dog
      ```
      And direct replacement produces:
      ```
          .    .    .    .    .    .    .    .    .    .
          The quick    brown                fox
              jumps    over the    lazy    dog
      ```
      When `1 TAB = 8 spaces`, snap-in replacement produces:
      ```
              .       .       .       .       .       .       .       .       .       .
              The quick       brown                               fox
                      jumps       over the        lazy        dog
      ```
      And direct replacement produces:
      ```
              .        .        .        .        .        .        .        .        .        .
              The quick        brown                                fox
                      jumps        over the        lazy        dog
      ```
      As you can see, misalignment increases with larger indentation lengths and
      the issue is aggravated by the fact that both white space and TAB are
      invisible characters, so it is easy to mistake ` \t \t` for `\t\t` when
      using snap-in replacement. On top of that, users often feel compelled to
      manually "fix" alignment issues using a mix of spaces and TABs which only
      contributes to make matters worse.

    - Finally, in order to be consistent with Zephry code bases, we adhere to
      the use of TABs for indentation for specific coding guidelines (e.g. C and
      CXX). In such cases, TABs are only allowed at the beginning of a line. Any
      other relative alignemnt must still be done with white spaces. The extra
      keystrokes are the price to pay for more predictability and less friction
      with Zephyr upstream.

## How to approach external dependencies

Remember the golden rule: **There ain't no such thing as a free lunch.**

It is a common mistake to take project dependencies for granted, specially in
open-source code bases. This is due to a misguided conviction that a
dependency (commercial or not), and open-source software (OSS) in particular:

1. Delivers on its promises;
2. Provides high quality work;
3. Provides the best solution for a problem;
4. Has a whole company/community/team working for you for free;
5. Is robust/secure because lots of people are constantly reviewing it
   (the `many eyes` principle is a falacy)

First consider that the majority of OSS is produced by individuals or small
groups with varying levels of expertise, for very limited purposes and for small
periods of time. Most are likely to be abandoned within a year of inception. Yet
the economical aspect of taking advantage of free-work is so appealing that,
according to some studies, more than 90% of commercial products rely on one or
more abandoned (or outdated) OSS project.

Then, for the small segment that is actively maintained, a second aspect becomes
key: control. What if the OSS project is deleted? What if its license changes?
What if the author and/or community refuses to apply a security patch? What if
its development direction changes and conflicts with your project direction?
What if the author/community refuses to implement a feature or bug-fix needed by
your project? What if it is discovered to violate someone's copyright?

It should be clear now that any external dependency is a weak spot and a
potential liability. It represents a piece of the project that is not completely
under our control, so we have to work in a way that mitigates potential risks.

As the Go proverb says:
[a little copying is better than a little depedency](https://www.youtube.com/watch?v=PAAkCSZUG1c&t=9m28s).

Mind that in a strict sense even the compiler is an external dependency. And so
is the operating system and the C runtime library, so there is no such thing as
a 100% dependency-free software. The trick is to strike a balance and stay
conscious of every time we trade control for convenience.

### Always work with forks

The main reason to use forks is to make sure that even if the author deletes
the repository, or changes the license, or sell the IP (and I have seen these
things happen more than once!) your project will continue to build.

Second, with your own fork you are the boss. You can create as many branches and
tags as you like for your own purposes without having to ask for permission from
the author. And more important, you can apply any code changes as you see fit
and still take advantage of Git to track those changes.

Of course, if you still want to be able to accept improvements from upstream
(and who does not?) care should be taken to minimize conflicts.

### Never alter upstream branches in a fork

Branches inherited from upstream should be considered reserved for incoming
upstream updates only. Think of it as the fork's input stream. This approach has
two main advantages:

1. These branches remain easily comparable to upstream branches to identify
   updates;

2. These branches will never conflict with upstream changes, they will always
   fast-forward;

### Never alter upstream tags in a fork

Tags inherited from upstream should be considered reserved for upstream updates
only. This is due to the fact that tags carry meaning and tags from upstream
are expected to always point to commit hashes fetched from upstream.

As consequence, the project must adhere to tag naming conventions that avoid
or minimize potential name clashes with upstream tags (e.g. use of a prefix)

### Use fork branches for modifications

Since we cannot modify branches originated in upstream, we have to create our
own fork branches if we want to introduce custom changes. This is more
convenient than manual patching with diff files because:

1. Changes can be tracked with contextual information (date, author,
   description and diff);

2. Eventual conflicts are limited, can be resolved in the fork branch and will
   not affect our ability to continue receiving updates from upstream;

3. Fork branches can be arbitrarily organized;

4. Fork branches do not need to include the whole set of commits from any
   upstream branch (one may cherry-pick changes if desired);

Naturally, it is important to adhere to a naming convention to avoid the risk of
name-clashes with upstream branches existing or to be created. The recommended
practice is to prefix all fork branches with the name of the project (or
initiative) followed by the name of the upstream branch it tracks. For example,
if the upstream branch is called `release/2.0` and our project is called
`foobar` the fork branch name would be `foobar/release/2.0`.

The same idea can be applied to tags.

### Minimize modifications in your fork branches

Because we have total control of our forks, we may be tempted into trying to
"fix" everything we can find in our fork branches, any minor violation, even
reformat the source code according to our standards. This is mistake. Remember
that every modification pushes our fork branch away from the upstream branch it
tracks and increases the likelyhood of conflicts when we try to merge in new
updates. Yes, fork branches are meant to be customized but changes should be
minimal. Many times it is better to live with that unformatted source code or
suboptimal function implementation if those files are likely to be modified in
the upstream as well. Leave conflict resolution for what is worth it.

Besides, always consider contributing to upstream first. Changing a fork branch
should be considered the last resort. If the change is required immeditely,
consider using a temporary fork branch where you have your patch now and a
cleaner one you can switch to once the patch is accepted upstream.

### Beware of third-party dependencies

It is easy to forget that dependencies of a dependency are yours too. This
extends to tools and in special to Git submodules.

If you fork a dependency you have to recursively fork all its submodules.
Otherwise, you fall into the trap of uncontrolled dependencies all the same.
Of course, you will have to correctly update the URLs and references of the
submodules in your fork branches to point to your forks. This is not difficult
but a long chain of sub-depedencies can easily grow into a lot of extra
maintenance work so be mindful of your dependencies. Always prefer
self-contained dependencies, that is those that do not bring more.

Be extra careful with projects that download content on demand as depedency
reference(s) may be buried in one or more build scripts. Some CMake projects
use [ExternalProject_FetchContent](https://cmake.org/cmake/help/latest/module/FetchContent.html)
with hardcoded URLs which will require patching. Zephyr uses West manifests, so
we can use [submanifests folder](firmware/zephyr/submanifests) to easily
override any Zephyr module.

Finally, beware of shared dependencies as they tend to complicate updates.
For example, say your project depends on A@v1.0 and B@v2.0 both which depend on
C@v1.0. Then one day you decide to update B to v3.0 but since it now depends on
C@v2.0 you have to update C as well only to realize this breaks A. So you have
to update A as well. At this point, if A does have an update available that
supports C@v2.0 consider yourself lucky! Chances are it does not, and you got
yourself locked with B@v2.0 and C@v1.0 until you can find a replacement for A.
This problem is extremely common with ubiquituous depedencies such as OpenSSL.

## Design Principles

### Nothing should depend on goodwill or common-sense

- Any policy, process or guideline that cannot be automatically verified and/or
  enforced SHOULD NOT be relied upon, no matter how good it seems to be,
  because someone at some point will overlook it (intentionally or not) and ever
  more often as the organization/project grows.

### [Least astonishment](https://en.wikipedia.org/wiki/Principle_of_least_astonishment)

- A component in a system should behave in a way that most users would expect it
  to behave. The behavior should not astonish or surprise users regardless of
  how much documentation you provide.

### [Least effort](https://en.wikipedia.org/wiki/Principle_of_least_effort)

- Prefer one-click builds when possible.

- Compiler errors and warnings are useful as they help to identify mistakes
  early. DO NOT silence or ignore warnings without a good reason and make sure
  to
  write down an explanation.

- Unit tests prevent regressions. Keep them up-to-date.

    - Unit tests should not be used to drive development. TDD is a mindless
      over-reaction to the fact that many developers fail to test their code at
      all. But testing requires a minimum amount of coherence and analysis
      before it can be effective in helping to detect implementation errors. In
      particular, it does not make any sense to think of unit tests if your code
      "units" are still in early development and thus in state of flow.

    - Unit tests are not supposed to explain or illustrate how soemthing works.
      Use comments in the source code for that.

    - Minimize testing. Tests multiply a code base maintenance cost by many
      times. Just do the math. At the very least for each function in a public
      API there should be another one for internal use only (no aggregated value
      for the use) but there are often more the one because of different use
      cases and possibilities of failure. Writing innefective tests or tests
      that only verify trivial things is a waste of resources.

- Any piece of information should have a single source of truth and should never
  have to be manually kept in sync with other locations unless the sync is
  automatic or (the sync is manual but) automatically verifiable.

- Use of design documents should be minimized as they tend to become either
  redundant or stale. A document that is read (or referred) once and never again
  is worthless at best because stale documentation quickly becomes misleading.
  Prefer storing information as close as possible to its source. For example,
  explain implementation details using comments in the source code instead of
  shiny Google Docs. Leave the shiny stuff for the marketing team.

- When possible (and necessary!) documentation should be generated using
  information from the source (code).

### [Semantic versioning](https://semver.org/)

- Version components MUST BE numeric and monotonic increasing (no exceptions!).

- Major change = Public Breaking change: a user has to act to make the product
  work in a pre-existing setup. Comparing the public properties of the product
  (API, requirements, dependencies, side effects, ...) will show one or more
  aspects that have been removed, modified or made MORE restrictive.

- Minor change = Public Non-Breaking change: a user does not have to do anything
  to make the product work in a pre-existing setup and might not even notice
  that an update happened. Comparing the public properties of the product (API,
  requirements, dependencies, side effects, ...) will show one or more aspects
  have been added or made LESS restrictive.

- Patch = Private Non-Breaking change: a user does not have to do anything to
  make it work in a pre-existing setup and cannot even verify that an update
  happened except by observing side effects (e.g. performance, accuracy, ...).
  Comparing the public properties of the product (API, requirements,
  dependencies, side effects, ...) will show no differences.

### Be nice to your future self

- DO NOT rely
  on [self-documenting code](https://en.wikipedia.org/wiki/Self-documenting_code).
  Source code is meant to communicate to a machine (the computer) and is
  inherently limited. It is not supposed to explain concepts, convey ideas or
  share opinions to other human beigs. Luckily we have English for that. Use it!

- DO NOT comment your code like a sports commentator. Explain what was on your
  mind not what the code is literally doing. This should steer you clear of
  useless remarks that only state the obvious (e.g. "// this line sets x to 2").

- Documentation should be located as close as possible to the source of truth.
  (e.g. in the source code rather than in a separate doc). Derived artifacts
  such as user manuals should be automatically generated from the source of
  truth.

- Code should be written with the reader's convenience in mind, not the
  writer's. Anything not obvious to a reader must be explained.

    - No unspoken assumptions. Always document pre-conditions and requirements.

    - Use assertions and qualifiers whenever possible.

    - Strongly typed languages are on your side not against you.

### Reduce noise

- Include-what-you-use (IWYU) for C/C++ source code.

- Out-of-source builds.

- Minimal tooling.

    - Minimum number of supported compilers (prefereably 1).

    - Minimum number of supported IDEs (preferably 1).

    - One build system to rule them all.

- Use precompiled binaries to alleviate host setup requirements.

### Correctness above all

- DO NOT speculate over correctness. If multiple solutions have been proposed,
  correctness must be established with tests before anything can be considered
  valid and compared.

- DO NOT even consider performance, cost or any other aspect until you have
  established correctness. In other words, correctness tests must be green.
  Remember: when correctness is not the first criteria of acceptance, an empty
  function is always the fastest and cheapest solution.

### Source code does not exist in a vacuum

- Use namespaces in C++ or an equivalent prefix convention in C to prevent name
  clashes in the public API (type, function and macro names) between your own
  code AND in special third-party code. Aesthetics is secondary.

- Naming conflicts and/or ambiguity can be particularly insidious to C macros.

- Prefer to work with a facade API (e.g. interface, wrapper library, typedefs,
  etc.) than call into thrid-party depedencies directly. The less your code
  relies on external dependencies the better. A facade limits the amount of code
  changes required when a dependency must be replaced or removed.

## Coding Guidelines

- [C](CODING_STYLE_C.md)
- [C++](CODING_STYLE_CXX.md)
- [CMAKE](CODING_STYLE_CMAKE.md)
- [DTC](CODING_STYLE_DTC.md)
- [KCONFIG](CODING_STYLE_KCONFIG.md)
- [PYTHON](CODING_STYLE_PYTHON.md)

## Known Issues

1. CMake 3.25 does not define `CMAKE_HOST_LINUX` correctly for WSL.

   **Workaround**: Perform string comparison to the value of
   `CMAKE_HOST_SYSTEM_NAME` instead.

2. Ninja prior to 1.12.0 has an open issue where the output is not flushed
   automatically after `\n` on Windows. This may lead to line fragments
   appearing in the console output and ultimately may lead to output from the
   console pool to be printed BEFORE the output of other jobs even when those
   jobs are already finished (e.g. misplaced output of an installation target
   appearing before the output of a build job dependency).

   See [#2143](https://github.com/ninja-build/ninja/pull/2143)

3. CLion 2024.1.1 only supports one form of custom region folding per file
   (the first one it encounters) and silently ignores all others. This means
   we cannot have `#pragma region` and `// region` in the same source file.
   This is a known issue in all IntelliJ IDEs.

   See [IDEA-233194](https://youtrack.jetbrains.com/issue/IDEA-233194/custom-folding-regions-do-not-work-when-mixing-region..endregion-and-editor-fold-comments).

4. Updating `submodules/llvm-project` does not trigger a rebuild of the `iwyu`.
   This happens because `submodules/iwyu` is the primary subdmoule for this
   package archive not `submodules/llvm-project`, which is just a third-party
   dependency.

   **Workaround**: Simply remove the `iwyu` archive(s) from the packages folder
   to force a rebuild after modifying `submodules/llvm-project`.

5. CMake running on WSL does not recognize lock files produced by a Windows
   native CMake instance.

   **Workaround**: Do not start CMake instances on both Windows and WSL in
   parallel. In CLion, go to `Settings->Advanced Settings` and under *CMake*
   check *Reload CMake profiles sequentially*. This will in effect force CLion
   to load all profiles sequentially even ones that might otherwise run in
   parallel but the impact is mitigated by the fact that CLion will invoke CMake
   only once for multi-config profiles that differ only by CMAKE_BUILD_TYPE.

6. CLion 2024.1.1 ignores the *Build Type* setting in the CMake profile if
   it was generated out of a CMake preset even for single-config generators.

   See [CPP-38167](https://youtrack.jetbrains.com/issue/CPP-38167)

   **Workaround**: In CLion, manually specify the desired build type using
   `-DCMAKE_BUILD_TYPE=<config>` after the `--preset` argument inside the
   *CMake options* edit box for the affected CMake profile. This is only needed
   when using a single-config generator.

7. CLion 2024.1.1 has no way to set up automatic generation of run/debug
   configurations for specific targets only. There is no support for
   USE_FOLDERS and the FOLDER target property either so depending on the
   project CLion will auto generate run/debug configurations for all
   third-party targets added via `add_subdirectory()`, `ExternalFetch` or
   `ExternalProject`.

   See [CPP-1688](https://youtrack.jetbrains.com/issue/CPP-1688)

   **Workaround**: Remove unwanted targets manually. Once removed, these targets
   will not be re-generated in the same workspace. Another option is to disable
   automatic generation of run/debug configurations altogether. In CLion, go to
   `Settings->Advance Settings` and under *Run/Debug* uncheck both
   *Generate configurations for new targets automatically* and
   *Delete configurations for missing targets automatically*

8. CLion 2024.1.1 cannot define custom editor scopes with exclusion patterns
   for files that are part of the CMake project but located outside of
   `CMAKE_SOURCE_DIR`. This may be an issue for projects that can be part of a
   larger parent project or projects that maintain the top-level
   `CMakeLists.txt` in a subfolder. For example:
   ```
   <PROJECT_ROOT_DIR>
           |
           |__ others
           |     |__ fooabar.c
           |
           |__ <CMAKE_SOURCE_DIR>
                       |__ src
                       |    |__ main.c
                       |
                       |__ CMakeLists.txt
   ```
   In this example, we can instruct CLion to open `<PROJECT_ROOT_DIR>` and use
   `<CMAKE_SOURCE_DIR>/CMakeLists.txt` as the top-level CMake file, but it is
   not possible to define a custom editor scope that recursively includes all
   `*.c` source files under `<CMAKE_SOURCE_DIR>` but excludes those under
   `others` using only relative paths.

   **Workaround**: Structure your project so that the top-level `CMakeLists.txt`
   is located in the project root folder and avoid referring to files outside of
   `CMAKE_SOURCE_DIR`.

9. Git has a limit of 4096 characters for a filename, except on Windows when
   Git is compiled with msys. It uses an older version of the Windows API and
   there is a limit of 260 characters for a filename.
   See https://gist.github.com/leodutra/a25bc1f51e8779943df0a95d5a4839d1
   See https://stackoverflow.com/a/22575737

   **Workaround**: If you run Windows 10 Home Edition you could change the
   registry to enable long paths. Go to
   `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem` in regedit
   and set `LongPathsEnabled` to 1. If you have Windows 10 Pro or Enterprise
   you could also use `Local Group Policies`. Go to
   `Computer Configuration->Administrative Templates->System->Filesystem` in
   `gpedit.msc`, open `Enable Win32 long paths` and set it to `Enabled`. Then
   in a command prompt enable long paths in Git with:
    ```
    $ git config --global core.longpaths true

10. CLion 2024.1.1 scope rules can only find files based on extension so file
    names without a dot (e.g. Kconfig) are not included.

    Se [CPP-???](https://youtrack.jetbrains.com/issue/CPP-???)

    **Workaround**: If files without extension must be searched use *Project*
    or *Directory* scopes.
