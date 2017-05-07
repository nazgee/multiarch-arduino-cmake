cmake_minimum_required (VERSION 2.8)

# file that contains runtime settings -- normally provided by Arduino IDE
set(ARDU_RUNTIME_CONFIG_FILE ${CMAKE_SOURCE_DIR}/runtime.txt)

# path to platform to be used
set(ARDU_PLATFORM_PATH "/home/nazgee/.arduino15/packages/esp8266/hardware/esp8266/2.3.0/")

# path to toolchain to be used (hopefully your polatform is supported)
set(CMAKE_TOOLCHAIN_FILE ${CMAKE_SOURCE_DIR}/cmake/ToolchainESP.cmake)

project(first C CXX ASM)
add_subdirectory(example)

