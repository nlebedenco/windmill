#include <windmill/dummy.h>

int windmill_dummy_get_value(int val)
{
    return (val != 0) ? val : CONFIG_WINDMILL_DUMMY_GET_VALUE_DEFAULT;
}
