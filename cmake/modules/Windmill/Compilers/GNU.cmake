include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

include(Windmill/Compilers/Common)

# Enable fast math floating point based on WINDMILL_ENABLE_FAST_MATH.
#
# Most of the "fast math" optimizations can be enabled/disabled individually, and -ffast-math enables all of them:
#
#    -ffinite-math-only
#    -fno-signed-zeros
#    -fno-trapping-math
#    -fassociative-math
#    -fno-math-errno
#    -freciprocal-math
#    -funsafe-math-optimizations
#    -fcx-limited-range
#
# This means we CANNOT have debug traps for NaN and devide-by-zero such as:
#
#    feenableexcept(FE_DIVBYZERO | FE_INVALID | FE_OVERFLOW);
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
# See https://gcc.gnu.org/onlinedocs/gcc-12.2.0/gcc/Optimize-Options.html#index-ffast-math
# See https://gcc.gnu.org/wiki/FloatingPointMath
# See https://stackoverflow.com/a/76684234
#
# NOTE: In Zephyr, slow performance of the trigonometric functions provided by newlib (libm) on ARM is a known upstream
#       newlib issue. It remains unknown if picolibc is affected the same way.
#
#       A workaround has been provided through the CMSIS-DSP library, which offers optimized trigonometric function
#       implementations for ARM targets.
#       See https://github.com/zephyrproject-rtos/zephyr/issues/23723
add_compile_options($<$<BOOL:${WINDMILL_ENABLE_FAST_MATH}>:-ffast-math>)
