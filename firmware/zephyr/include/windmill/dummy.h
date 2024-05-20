#ifndef WINDMILL_DUMMY_H_
#define WINDMILL_DUMMY_H_

/**
 * @defgroup windmill_lib_dummy Dummy library
 * @ingroup lib
 * @{
 *
 * @brief An example of a custom out-of-tree library.
 *
 * This library illustrates how create custom out-of-tree libraries. Splitting
 * code in libraries enables code reuse and modularity, also easing testing.
 */

/**
 * @brief Return @p val if non-zero, or Kconfig-controlled default.
 *
 * Function returns the provided value if non-zero, or a Kconfig-controlled
 * default value if the parameter is zero. This trivial function is provided in
 * order to have a library interface example that is trivial to test.
 *
 * @param val Value to return if non-zero
 *
 * @retval val if @p val is non-zero
 * @retval CONFIG_WINDMILL_DUMMY_GET_VALUE_DEFAULT if @p val is zero
 *
 * @note Zephyr only supports static libraries so there is no need to decorate functions with an export macro unless the
 * code is shared with desktop or mobile builds.
 */
int windmill_dummy_get_value(int val);

/** @} */

#endif /* WINDMILL_DUMMY_H_ */
