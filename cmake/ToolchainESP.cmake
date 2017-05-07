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
    arduconfig_set_property("upload.verbose" "-vv")
    arduconfig_set_property("build.arch" "ESP8266")
endif()

arduconfig_init()

# upload tool and the way it's configured is different for all Arduiono boards
# hence it's not handled by autoconfig
if (NOT ESP8266_AUTOCONFIG_DONE)
    # "tools.esptool.upload.pattern" property expects "path" and "cmd"
    # properties to point to esptool binary. In order to allow full resolution
    # of "tools.esptool.upload.pattern" property, these variables are faked:
    arduconfig_set_property_from_other("path" "tools.esptool.path")       
    arduconfig_set_property_from_other("cmd" "tools.esptool.cmd")
    
    # once "cmd" and "path" properties are properly set above, full
    # property resolution below will work just fine, and ARDU_RECIPE_UPLOAD
    # will contain a properly resolved recipe
    arduconfig_export_ardu_variable(RECIPE_UPLOAD "tools.esptool.upload.pattern")
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









