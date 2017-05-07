set(CMAKE_SYSTEM_NAME Arduino)

# Add current directory to CMake Module path automatically
if(EXISTS  ${CMAKE_CURRENT_LIST_DIR}/Platform/Arduino.cmake)
    set(CMAKE_MODULE_PATH  ${CMAKE_MODULE_PATH} ${CMAKE_CURRENT_LIST_DIR})
endif()

include(ArduConfig)

# some of the variables are provided by arduino ide, so they are not present
# in any of the config files we parse. To avoid causing issues for user we
# define all board-specific variables here, so user has to provide only
# really essential variables RUNTIME_* variables
if (NOT ESP8266_ARDU_CONFIG_DONE)
    set(RUNTIME_upload.verbose "-vv" CACHE INTERNAL "")
    set(RUNTIME_build.arch "ESP8266" CACHE INTERNAL "")
endif()

ardu_config()

# upload tool and the way it's configured is different for all Arduiono boards
# hence it's not handled by autoconfig
if (NOT ESP8266_AUTOCONFIG_DONE)
    ardu_config_export_value(ARDU_ESPTOOL_PATH "tools.esptool.path")
    set(RUNTIME_path "${ARDU_ESPTOOL_PATH}" CACHE INTERNAL "")
    ardu_config_export_value(ARDU_ESPTOOL_CMD "tools.esptool.cmd")
    set(RUNTIME_cmd "${ARDU_ESPTOOL_CMD}" CACHE INTERNAL "")
    ardu_config_export_value(ARDU_RECIPE_UPLOAD "tools.esptool.upload.pattern")
endif()

set(ESP8266_ARDU_CONFIG_DONE true CACHE INTERNAL "")

include(CMakeForceCompiler)
cmake_force_c_compiler(${ARDU_GCC_BINARY} GNU)
cmake_force_cxx_compiler(${ARDU_CXX_BINARY} GNU)

# set custom recipe for .o files building
set(CMAKE_C_COMPILE_OBJECT "${ARDU_RECIPE_OBJ_C}" CACHE FORCE "")
set(CMAKE_CXX_COMPILE_OBJECT "${ARDU_RECIPE_OBJ_CXX}" CACHE FORCE "")
#set(CMAKE_C_LINK_EXECUTABLE "${ARDU_RECIPE_LINK}" CACHE FORCE "")
#set(CMAKE_CXX_LINK_EXECUTABLE "${ARDU_RECIPE_LINK}" CACHE FORCE "")

# this function is called 'late' and allows us to force 'last-minute' fixes
function(toolchain_init)
    # workaround for ESP -- only .o files are defined in linker, so we must force .o extension
    SET(CMAKE_C_OUTPUT_EXTENSION ".o" PARENT_SCOPE)
    SET(CMAKE_CXX_OUTPUT_EXTENSION ".o" PARENT_SCOPE)
endfunction()









