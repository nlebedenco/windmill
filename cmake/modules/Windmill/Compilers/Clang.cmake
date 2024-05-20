include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

include(Windmill/Compilers/Common)

# Enable fast math floating point based on WINDMILL_ENABLE_FAST_MATH.
#
# -ffast-math also defines the __FAST_MATH__ preprocessor macro. Some math libraries recognize this macro and change
# their behavior. With the exception of -ffp-contract=fast, using any of the options below to disable any of the
# individual optimizations in -ffast-math will cause __FAST_MATH__ to no longer be set.
#
# This option implies:
#
#    -ffinite-math-only
#    -fno-signed-zeros
#    -fno-trapping-math
#    -fassociative-math
#    -fno-math-errno
#    -freciprocal-math
#    -fno-honor-infinities
#    -fno-honor-nans
#    -fapprox-func
#    -fno-rounding-math
#    -ffp-contract=fast
#
#
# Note: -ffast-math causes crtfastmath.o to be linked with code.
#
# Under -ffast-math (or /fp:fast), the compiler generates code intended to run in the default floating-point environment
# and assumes the floating-point environment isn't accessed or modified at runtime. That is, it assumes the code leaves
# floating-point exceptions masked, doesn't read or write floating-point status registers, and doesn't change rounding
# modes.
#
# This means we CANNOT have debug traps for NaN and devide-by-zero such as:
#
#    feenableexcept(FE_DIVBYZERO | FE_INVALID | FE_OVERFLOW);
#
#    OR (on Windows)
#
#    #ifndef NDEBUG
#    _clearfp();
#    _controlfp(_controlfp(0, 0) & ~(_EM_INVALID | _EM_ZERODIVIDE | _EM_OVERFLOW), _MCW_EM);
#    #endif
#
# The floating-point format has a special representation for values that are close to 0.0. These "subnormal" numbers
# (also called "denormals") are very costly in some cases because the CPU handles subnormal results using microcode
# exceptions. The x86_64 CPU has a feature to treat subnormal input as 0.0 and flush subnormal results to 0.0,
# eliminating this performance penalty. This can be enabled by:
#
#     #define MXCSR_DAZ (1<<6)    /* Enable "denormals are zero" mode */
#     #define MXCSR_FTZ (1<<15)   /* Enable "flush to zero" mode */
#
#     unsigned int mxcsr = __builtin_ia32_stmxcsr();
#     mxcsr |= MXCSR_DAZ | MXCSR_FTZ;
#     __builtin_ia32_ldmxcsr(mxcsr);
#
# Linking with -ffast-math disables subnormal numbers for the application by adding code such as the above in a global
# constructor that runs before main.
#
# See https://releases.llvm.org/17.0.1/tools/clang/docs/UsersManual.html#cmdoption-ffast-math
# See https://learn.microsoft.com/en-us/cpp/build/reference/fp-specify-floating-point-behavior?view=msvc-170#fast
if (MSVC) # clang-cl
    add_compile_options($<$<BOOL:${WINDMILL_ENABLE_FAST_MATH}>:/fp:fast>)
else ()
    add_compile_options($<$<BOOL:${WINDMILL_ENABLE_FAST_MATH}>:-ffast-math>)
endif ()
