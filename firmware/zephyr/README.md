This directory contains Zephyr extensions and it is automatically added as a zephyr module because:

1. It is named "zephyr"
2. It is located in the west manifest folder (i.e. the same folder where west.yml is placed)
3. It contains a module configuration file (module.yml)

This directory is NOT the Zephyr RTOS source code. Refer to <PROJECT_ROOT>/firmaware/west.yml to determine where zephyr
sources are located. Usually this should be at <PROJECT_ROOT>/.external/zephyr.
