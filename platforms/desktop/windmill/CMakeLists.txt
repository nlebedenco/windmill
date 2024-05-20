########################################################################################################################
# Sources
########################################################################################################################
# We cannot simply list all subdirectories and add each one in a loop because the order we add subdirectories may be
# important. For example, for an executable that depends on a library, the library subdirectory must be added first.
add_subdirectory(empty)
