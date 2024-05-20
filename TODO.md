# TODO

- Finish the explanation of the role of each CMake list file in the comments of
  the top-level CMakeLists.txt
- clang-format rules compatible with Zerphy coding guidelines
- git pre-commit check to enforce git commit messages following Zephyr
  guidelines
- Instructions for CLion
- Instructions for VSCode
- Coding Style C
- Coding Style CMAKE
- Coding Style DTC
- Coding Style KCONFIG
- Coding Style PYTHON
- Recommended user gitconfig options
- Explain the project base script (windmill and windmill.cmd) and why we do not
  simply rely on custom West commands
- Explain the content of .west/config
- Explain recommended approach to semantic versioning
- Explain supported configuration types and how the implementation diverges from
  common practice in Zephyr projects
- Explain the use of forks and how to override external references in West to
  use forks
- Explain the use of 4-space indentation instead of 2 in markdown files
- Explain why only Zephyr SDK is supported
- Complete the information about how to configure Toolchains in CLion for
  Windmill
- Explain in detail how to duplicate Clion build profiles created from CMake
  presets to build for different config types
- Explain use of CMake presets
- Explain how to install extras/clion/TextMate/kconfig template for syntax
  highlight in CLion
- Test build for Linux on Windows host using WSL
- Test build for Linux on Linux host
- Test build for Darwin on macOS host
- Test build for Android on Linux host
- Test build for Android on macOs host
- Explain compiler choices and compatibility level
- Describe use and limitations of bundled tools: iwyu, cppcheck
- Explain how to mark external folders as "Excluded"  in CLion to avoid
  unecessary indexing
- Warn Windows users to ensure that the VC runtime used to build Windows targets
  is the less or equal to VC runtime installed in the Windows host. Beware that
  sometimes Visual Studio ships with a VC runtime version ahead of the
  latest redistributable.
  List Visual Studio Components required
  Known issue: CLion scope does not detect Kconfig files
- Explain that packages are rebuilt if there is any difference in
    * COMMIT
    * RELATIVE_PATH
    * REVISION
    * ORIGIN URL
      Highlight that locally altered files cause git to report REVISION-dirty
      which may trigger a package rebuild
- Implement the python windmill script for common tasks such as git status
  including submodules, git sync of submodules and code format
- Explain how to exclude folders from indexing and search in CLion (double clock
  gitignore, select view directories and select all but .external and .stage)
- Explain the zephyr module, example board and example application are based on
  Zephyr's example-application repository
- Recommend gitconfig with fatal error in case of EOL mismatch in file
- Explain why prefixing is important for CMake functions and variables and for C
  functions and macros
- Proper clang-format and clang-tidy configuration for the Zephyr modelu folder
- Double-check format of everything (Cmake files and sources)
- Configure cmake-format
- Double-check pre-commit is checking clang-format and cmake-format
