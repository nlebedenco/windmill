# This rule file assumes the compiler is clang-cl.
#
# Clang has support for many extensions from Microsoft Visual C++ which are already enabled by default in clang-cl.
# It does not implement every pragma or declspec provided by MSVC, but the popular ones, such as __declspec(dllexport)
# and #pragma comment(lib) are well supported. Clang has -fms-compatibility and -fms-compatibility-version flags that
# make clang accept enough invalid C++ to be able to parse most Microsoft headers. For example, it allows unqualified
# lookup of dependent base class members, which is a common compatibility issue with clang. These flags are also enabled
# by default in clang-cl which tries to discover the MSVC installation and then matches the compatibility version
# (_MSC_VER) to that of the system runtime libraries.
# See https://clang.llvm.org/docs/UsersManual.html#microsoft-extensions
#
# Option /volatile:iso ensures volatile loads and stores have standard semantics
# DO NOT pass /DUNICODE here. Windows unicode support should be an option reserved for each project configuration.
# DO NOT pass /utf-8 here. Source code support for utf-8 should be an option reserved for each project configuration.
# The same applies to /source-charset, /execution-charset or /validate-charset
#
# /Brepro is an undocumented flag from MSVC but helps with making builds more reproducible by avoiding putting
# timestamps into object files - which are not needed if incremental linking is not used. It must also be passed to the
# linker.
#
# See https://blog.llvm.org/2019/11/deterministic-builds-with-clang-and-lld.html
# See https://github.com/rust-lang/cc-rs/issues/373
#
# MSVC Optimization levels:
#
# Option | Description                 | Implies
# -------|-----------------------------|--------------------------------
# /Od    | No optimization (default)   |  /Ob0
# /O1    | Minimize Size	           |  /Og /Os /Oy /Ob2 /GF /Gy
# /O2    | Maximize Speed	           |  /Og /Oi /Ot /Oy /Ob2 /GF /Gy
#-----------------------------------------------------------------------
# Static libraries or object files compiled using the /GL (Whole program optimization) compiler switch or linked using
# /LTCG (Link-time code generation) aren't binary-compatible across versions, including minor version updates. All
# object files and libraries compiled using /GL and /LTCG must use exactly the same toolset for the compile and the
# final link. For example, code built by using /GL in the Visual Studio 2019 version 16.7 toolset can't be linked to
# code built by using /GL in the Visual Studio 2019 version 16.8 toolset. The compiler emits Fatal error C1047.
# See https://learn.microsoft.com/en-us/cpp/porting/binary-compat-2015-2017?view=msvc-170#restrictions
#
# MSVC does not have a strict aliasing compiler option but Clang does. It remains unclear however whether clang-cl
# defaults to -fno-strict-aliasing. Note that MSVC does support aliasing rules with extensions
# (e.g. __declspec(noalias))
#
# See https://learn.microsoft.com/en-us/cpp/cpp/noalias
# See https://learn.microsoft.com/en-us/cpp/cpp/restrict
#
# DO NOT pass -flto here. This is controlled by CMAKE_INTERPROCEDURAL_OPTIMIZATION.
# Also note that LTO may break binary compatibility for pre-compiled static libraries.
#
# See https://cmake.org/cmake/help/latest/variable/CMAKE_INTERPROCEDURAL_OPTIMIZATION.html
#
# DO NOT pas /fp:fast here. This is controlled by WINDMILL_ENABLE_FAST_MATH.
#
# Use /RTC for development builds only. Don't use /RTC for a release build. Option /RTC can't be used with compiler
# optimizations (/O Options (Optimize Code)). A program image built with /RTC is slightly larger and slightly slower
# than an image built with /Od (up to 5 percent slower than an /Od build). The __MSVC_RUNTIME_CHECKS preprocessor
# directive will be defined when you use any /RTC option or /GZ.
#
# Note that /Gs and /GS are different options. The former enables Control Stack Probe Calls while the latter enables
# Buffer Security Checks. We do not pass /Gs in CFLAGS because there might be a significant trade-off between security
# and performance. Mind that passing /Gs0, for example, will initiate stack probes for every function call that requires
# storage for local variables which may have a big performance impact. For x64 targets, if the /Gs option is specified
# without a size argument, it is the same as /Gs0. If the size argument is 1 through 9, warning D9014 is emitted, and
# the effect is the same as specifying /Gs0. For x86, ARM, and ARM64 targets, the /Gs option without a size argument is
# the same as /Gs4096. If the size argument is 1 through 9, warning D9014 is emitted, and the effect is the same as
# specifying /Gs4096. The default value of /Gs4096 allows the program stack of applications for Windows to grow
# correctly at run time. Note that /Gs and the check_stack pragma have no effect on standard C library routines; they
# affect only the functions you compile.
#
# Option /GS (Buffer Security Check) is on by default.
# Option /Zc:threadSafeInit (thread-safe static initialization) is enabled by default
#
# DO NOT pass options /Zi or /Z7 here. This is controlled by CMAKE_MSVC_DEBUG_INFORMATION_FORMAT.
#
# In clang-cl, -Wall is an alias to -Weverything to emulate the behaviour or -Wall in MSVC so we actually want /W4
# which is the equivalent to GCC's -Wall -Wextra.
# In MSVC and clang-cl warning 4714 indicates that a function marked as __forceinline was not inlined. This is treated
# as an error to force a code fix (either remove the forced inline attribute or downgrade to a discretionary inline)
# See https://clang.llvm.org/docs/UsersManual.html#clang-cl
# See https://reviews.llvm.org/D40603
# See https://quuxplusone.github.io/blog/2018/12/06/dont-use-weverything/
# See https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-4-c4714?view=msvc-170

# cmake-format: off

set(CMAKE_C_FLAGS_INIT                  /diagnostics:caret /volatile:iso /Brepro)

# cmake-format: on

if ("${CMAKE_SYSTEM_PROCESSOR}" MATCHES "^([Xx]86|[Ii]686)$")
    list(APPEND CMAKE_C_FLAGS_INIT -m32 /arch:SSE2)
elseif ("${CMAKE_SYSTEM_PROCESSOR}" MATCHES "^([Aa][Mm][Dd]64|[Xx]86_64|[Xx]64)$")
    list(APPEND CMAKE_C_FLAGS_INIT -m64 /arch:AVX2)
elseif ("${CMAKE_SYSTEM_PROCESSOR}" MATCHES "^([Aa][Rr][Mm]64|[Aa][Aa][Rr][Cc][Hh]64)$")
    list(APPEND CMAKE_C_FLAGS_INIT /arch:armv8.2)
endif ()

# cmake-format: off

list(APPEND CMAKE_C_FLAGS_INIT          /Gs4096 -Werror=vla /W4 -Werror=unknown-argument -Werror=unused-result -Wpacked
                                        -DWIN32 -D_WINDOWS)

set(CMAKE_C_FLAGS_DEBUG_INIT            /Od -fno-strict-aliasing /Gy /RTC1 -D_DEBUG)
set(CMAKE_C_FLAGS_RELEASE_INIT          /O2 -fno-strict-aliasing -DNDEBUG)
set(CMAKE_C_FLAGS_RELWITHDEBINFO_INIT   /O2 -fno-strict-aliasing -DNDEBUG)
set(CMAKE_C_FLAGS_MINSIZEREL_INIT       /O1 -fno-strict-aliasing -DNDEBUG)

# As of version 15, Clang still requires the user to explicitly enable matching of `template template` parameters to
# compatible arguments. Despite being the resolution to a Defect Report (P0522R0), this feature is disabled by default
# in all language versions because the change to the standard lacks a corresponding change for template partial
# ordering, resulting in ambiguity errors for reasonable and previously-valid code. This issue is expected to be
# rectified soon. Note this option cannot be used on Windows because clang-cl does not support
# "-frelaxed-template-template-args".
# See https://clang.llvm.org/cxx_status.html#p0522
#
# MSVC enables /Zc:sizedDealloc and /Zc:alignedNew by default for C++17 but clang-cl needs it to be explicit.
#
# Option /GR ((Enable RTTI) is on by default. Use /GR- to disable RTTI.
#
# Clang can disable exceptions with -fno-exceptions (also the default) so that any use of try/catch/throw will raise
# a compiler error. This is different in MSVC which cannot disable exceptions but only change how the stack unwinds.
# Many authors recommend to disable Exceptions and in fact most C++ game engines do so to reduce code bloat and create
# more opportunities for code inlining. Unfortunately, this practice does compromise RAII in situations where resource
# aquisition may fail (e.g. memory allocation). Without exceptions, in such cases it is impossible to guarantee that an
# object is valid after construction and all  strategies proposed to date (initializer functions, static constrcutors,
# etc...) have to sacrifice some aspect of the language or require intrusive code patterns (explicit validity checks
# required, ability to inherit behaviour including resource aquisition may be lost, destructors have to deal with all
# possible error cases, reduced composability, etc)
#
# Full compiler support for the Standard C++ exception handling model that safely unwinds stack objects requires /EHsc
# (recommended), /EHs, or /EHa. If you use /EHs or /EHsc, then your catch(...) clauses don't catch asynchronous
# structured exceptions (SEH). Any access violations and managed System.Exception exceptions go uncaught. By default,
# the compiler supports SEH handlers in the native C++ catch(...) clause. However, it also generates code that only
# partially supports C++ exceptions. The default exception unwinding code doesn't destroy automatic C++ objects outside
# of try blocks that go out of scope because of an exception. In this case, resource leaks and undefined behavior may
# result when a C++ exception is thrown.
#
# Note that SEH support in clang-cl is partial. Structured exceptions (__try / __except / __finally) mostly work on x86
# and x64. LLVM does not model asynchronous exceptions, so it is currently impossible to catch an asynchronous exception
# generated in the same frame as the catching __try.
#
# Note that Microsoft strongly advises to never link object files compiled using /EHa to ones compiled using /EHs or
# /EHsc in the same executable module. If you have to handle an asynchronous exception by using /EHa anywhere in your
# module, use /EHa to compile all the code in that module. Beware that using /EHa will allow the program to catch
# exceptions that should lead to program termination such as access violation and stack overflow.
# See https://learn.microsoft.com/en-us/cpp/build/reference/eh-exception-handling-model
# See https://stackoverflow.com/a/4574319
#
# clang-cl prior to 13 requires _HAS_STATIC_RTTI=0 to be passed explicitly when RTTI is disabled.
# See https://github.com/llvm/llvm-project/commit/936d6756ccfbe207a181b692b828f9fd8f1489f2
#
# FIXME: using dash instead of slash (e.g. -EHs and not /EHs) for clang-tidy to work
#        See https://gitlab.kitware.com/cmake/cmake/-/issues/20512
set(CMAKE_CXX_FLAGS_INIT                ${CMAKE_C_FLAGS_INIT} /Zc:sizedDealloc /Zc:alignedNew -EHsc)
set(CMAKE_CXX_FLAGS_DEBUG_INIT          ${CMAKE_C_FLAGS_DEBUG_INIT})
set(CMAKE_CXX_FLAGS_RELEASE_INIT        ${CMAKE_C_FLAGS_RELEASE_INIT})
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO_INIT ${CMAKE_C_FLAGS_RELWITHDEBINFO_INIT})
set(CMAKE_CXX_FLAGS_MINSIZEREL_INIT     ${CMAKE_C_FLAGS_MINSIZEREL_INIT})

# llvm-rc only supports arguments with dash (-), not slash (/)
# NLS conversion uses UTF-8 (code page 65001 == UTF-8)
set(CMAKE_RC_FLAGS_INIT -c65001)


# The /OPT arguments may be specified together, separated by commas. For example, instead of /OPT:REF /OPT:NOICF,
# you can specify /OPT:REF,NOICF. When used at the command line, the linker defaults to /OPT:REF,ICF,LBR. If /DEBUG
# is specified, the default is /OPT:NOREF,NOICF,NOLBR. Microsoft documentation states that /INCREMENTAL is enabled by
# default but also says that it is disabled when
#     /OPT:REF is selected
#     /OPT:ICF is selected
#     /OPT:LBR is selected
#     /ORDER is selected
# Since the linker default is /OPT:REF,ICF,LBR then incremental link can only be disabled by default as well unless
# /DEBUG is specified (which implies /INCREMENTAL) in which case we have to explicitly enable /OPT options.
#
# CMake already embeds a manifest into the final binary so there is no need to pass /MANIFEST:EMBED (in fact it might
# even break CMake's compiler checks)
# See https://gitlab.kitware.com/cmake/cmake/-/blob/v3.24.1/Source/cmcmd.cxx#L2310
#
# Options /DYNAMICBASE (Generate PIE code for ASLR) and /HIGHENTROPYVA (High entropy ASLR for 64 bits targets) are
# enabled by default.
#
# CET requires specific hardware support and thus should not be set here.
# See https://stackoverflow.com/a/70911025
#
# Always use /DEBUG:FULL because lld-link does not support /DEBUG:FASTLINK
# Despite the variable name there is no actual linking involved in static libraries
#
# /Brepro is an undocumented flag from MSVC but helps with making builds more reproducible by avoiding putting
# timestamps into object files - which are not needed if incremental linking is not used. It is incompatible with
# incremental builds (e.g. /LTCG:INCREMENTAL)
#
# See https://blog.llvm.org/2019/11/deterministic-builds-with-clang-and-lld.html
# See https://nikhilism.com/post/2020/windows-deterministic-builds/
# See https://github.com/rust-lang/cc-rs/issues/373

set(CMAKE_EXE_LINKER_FLAGS_INIT                     /nologo /Brepro /WX)
set(CMAKE_EXE_LINKER_FLAGS_DEBUG_INIT               /DEBUG:FULL /INCREMENTAL:NO /OPT:REF,ICF)
set(CMAKE_EXE_LINKER_FLAGS_RELEASE_INIT             /INCREMENTAL:NO)
set(CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO_INIT      /DEBUG:FULL /INCREMENTAL:NO)
set(CMAKE_EXE_LINKER_FLAGS_MINSIZEREL_INIT          /INCREMENTAL:NO)

set(CMAKE_SHARED_LINKER_FLAGS_INIT                  /nologo /Brepro /WX)
set(CMAKE_SHARED_LINKER_FLAGS_DEBUG_INIT            /DEBUG:FULL /INCREMENTAL:NO /OPT:REF,ICF)
set(CMAKE_SHARED_LINKER_FLAGS_RELEASE_INIT          /INCREMENTAL:NO /OPT:REF,ICF,LBR)
set(CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO_INIT   /DEBUG:FULL /INCREMENTAL:NO /OPT:REF,ICF,LBR)
set(CMAKE_SHARED_LINKER_FLAGS_MINSIZEREL_INIT       /INCREMENTAL:NO /OPT:REF,ICF,LBR)

set(CMAKE_MODULE_LINKER_FLAGS_INIT                  /nologo /Brepro /WX)
set(CMAKE_MODULE_LINKER_FLAGS_DEBUG_INIT            /DEBUG:FULL /INCREMENTAL:NO /OPT:REF,ICF)
set(CMAKE_MODULE_LINKER_FLAGS_RELEASE_INIT          /INCREMENTAL:NO)
set(CMAKE_MODULE_LINKER_FLAGS_RELWITHDEBINFO_INIT   /DEBUG:FULL /INCREMENTAL:NO /OPT:REF,ICF,LBR)
set(CMAKE_MODULE_LINKER_FLAGS_MINSIZEREL_INIT       /INCREMENTAL:NO)

set(CMAKE_STATIC_LINKER_FLAGS_INIT                  /nologo)
set(CMAKE_STATIC_LINKER_FLAGS_DEBUG_INIT            "")
set(CMAKE_STATIC_LINKER_FLAGS_RELEASE_INIT          "")
set(CMAKE_STATIC_LINKER_FLAGS_RELWITHDEBINFO_INIT   "")
set(CMAKE_STATIC_LINKER_FLAGS_MINSIZEREL_INIT       "")

# cmake-format: on

foreach (lang IN ITEMS C CXX RC EXE_LINKER SHARED_LINKER MODULE_LINKER STATIC_LINKER)
    foreach (config IN ITEMS "" _DEBUG _RELEASE _RELWITHDEBINFO _MINSIZEREL)
        if (DEFINED CMAKE_${lang}_FLAGS${config}_INIT)
            string(REPLACE ";" " " CMAKE_${lang}_FLAGS${config}_INIT "${CMAKE_${lang}_FLAGS${config}_INIT}")
        endif ()
    endforeach ()
endforeacH ()
