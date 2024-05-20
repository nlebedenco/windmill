include_guard(DIRECTORY)
message(STATUS "Including ${CMAKE_CURRENT_LIST_FILE}")

# This option enables an static analysis of program flow which looks for "interesting" interprocedural paths through the
# code, and issues warnings for problems found on them. It is much more expensive than other GCC warnings.
#
# This option is only available if GCC was configured with analyzer support enabled.
#
# Enabling this option effectively enables the following warnings:
#
#   -Wanalyzer-double-fclose
#   -Wanalyzer-double-free
#   -Wanalyzer-exposure-through-output-file
#   -Wanalyzer-file-leak
#   -Wanalyzer-free-of-non-heap
#   -Wanalyzer-malloc-leak
#   -Wanalyzer-mismatching-deallocation
#   -Wanalyzer-null-argument
#   -Wanalyzer-null-dereference
#   -Wanalyzer-possible-null-argument
#   -Wanalyzer-possible-null-dereference
#   -Wanalyzer-shift-count-negative
#   -Wanalyzer-shift-count-overflow
#   -Wanalyzer-stale-setjmp-buffer
#   -Wanalyzer-unsafe-call-within-signal-handler
#   -Wanalyzer-use-after-free
#   -Wanalyzer-use-of-pointer-in-stale-stack-frame
#   -Wanalyzer-use-of-uninitialized-value
#   -Wanalyzer-write-to-const
#   -Wanalyzer-write-to-string-literal
#
# See https://gcc.gnu.org/onlinedocs/gcc-12.2.0/gcc/Static-Analyzer-Options.html
add_compile_options($<$<AND:$<C_COMPILER_ID:GNU>,$<BOOL:${WINDMILL_ENABLE_GCC_ANALYZER}>>:-fanalyzer>)
