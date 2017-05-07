###################################################################
function(arduconfig_cache_shallow_properties CONFIG_FILE)
        if(EXISTS ${CONFIG_FILE})
             # Settings file split into lines
            file(STRINGS ${CONFIG_FILE} FILE_ENTRIES)
   
            foreach(FILE_ENTRY ${FILE_ENTRIES})
                if("${FILE_ENTRY}" MATCHES "^[^#]+")
                    string(REGEX MATCH "^[^=]*" SETTING_NAME  ${FILE_ENTRY})
                    string(REPLACE "${SETTING_NAME}=" ""  SETTING_VALUE ${FILE_ENTRY})
                    string(STRIP "${SETTING_VALUE}" SETTING_VALUE)               
    
                    if (NOT SETTING_VALUE) 
                        set(SETTING_VALUE " ")
                    endif()
                    # store token and it's value as RUNTIME_ cache variable
                    # e.g.: "RUNTIME_compiler.path" variable can hold "/usr/bin/" value
                    arduconfig_set_property(${SETTING_NAME} "${SETTING_VALUE}")
#                    message(STATUS "Cached \"RUNTIME_${SETTING_NAME}\" variable with <${SETTING_VALUE}> value")
                endif()
            endforeach()
        else()
            message(WARNING "Config file does not exist: ${CONFIG_FILE}")
        endif()
endfunction()

###################################################################
# looks up a TOKEN's value in the following locations:
# 1. among RUNTIME_* variables
# 2. in given CONFIG_FILE
# 3. in file pointed to by ARDU_RUNTIME_CONFIG_FILE variable
function(arduconfig_get_property_shallow OUT_VAR_TO_SET TOKEN CONFIG_FILE)
    set(MATCHER "${TOKEN}=")
    
    unset(SETTING_VALUE)
    
    set(PROPERTY_VARIABLE "RUNTIME_${TOKEN}")
    
    if (${PROPERTY_VARIABLE})
#        message(STATUS "Token \"${TOKEN}\" resolved with runtime variable \"${PROPERTY_VARIABLE}\" = <${${PROPERTY_VARIABLE}}>")
        set(SETTING_VALUE ${${PROPERTY_VARIABLE}})
    else()
#        message(STATUS "Token \"${TOKEN}\" NOT resolved with runtime variable \"${PROPERTY_VARIABLE}\"")
        if(EXISTS ${CONFIG_FILE})
             # Settings file split into lines
            file(STRINGS ${CONFIG_FILE} FILE_ENTRIES)
#            message(STATUS "Config loading to ${OUT_LIST_TO_APPEND} from ${CONFIG_FILE}")
        
            foreach(FILE_ENTRY ${FILE_ENTRIES})
                if("${FILE_ENTRY}" MATCHES "^${MATCHER}")
#                    message(STATUS "Config really parsing ${FILE_ENTRY}")
                    string(REGEX MATCH "^[^=]*" SETTING_NAME  ${FILE_ENTRY})
                    string(REPLACE "${SETTING_NAME}=" ""  SETTING_VALUE ${FILE_ENTRY})
                    string(STRIP "${SETTING_VALUE}" SETTING_VALUE)               
#                    message(STATUS "Config parsed ${SETTING_NAME}  =  ${SETTING_VALUE}")
                endif()
            endforeach()
        else()
            message(WARNING "Config file does not exist: ${CONFIG_FILE}")
        endif()
    endif()

    if (NOT SETTING_VALUE) 
        # still no value found? try in runtime.txt config file
        if (CONFIG_FILE STREQUAL ARDU_RUNTIME_CONFIG_FILE)
            message(STATUS "No more resolutions for \"${TOKEN}\"; already tried ARDU_RUNTIME_CONFIG_FILE and RUNTIME_* variables")
        else()
            # trying runtime.txt makes sense only if we're currently not processing different file
            arduconfig_get_property_shallow(SETTING_VALUE ${TOKEN} ${ARDU_RUNTIME_CONFIG_FILE})
        endif()
    endif()

    if (NOT SETTING_VALUE)
        message(FATAL_ERROR "Token \"${TOKEN}\" not found in ${CONFIG_FILE}, please provide <${PROPERTY_VARIABLE}> variable or add \"${TOKEN}=\" entry to ARDU_RUNTIME_CONFIG_FILE=${ARDU_RUNTIME_CONFIG_FILE}")
    endif()

    # push returned value to the caller's scope
    set(${OUT_VAR_TO_SET} "${SETTING_VALUE}" PARENT_SCOPE)
endfunction()

###################################################################
function(arduconfig_get_property_deep OUT_VAR_TO_SET TOKEN CONFIG_FILE )
    set(TEMP_VALUE "UNRESOLVED_${TOKEN}_ENTRY")
    arduconfig_get_property_shallow(TEMP_VALUE ${TOKEN} ${CONFIG_FILE})

    set(UNRESOLVED_TOKENS)
    if (TEMP_VALUE)
        string(REGEX MATCHALL "{[^{}]*}" UNRESOLVED_TOKENS ${TEMP_VALUE})
    elseif()
        # this can happen if config value was empty
    endif()

    if (UNRESOLVED_TOKENS)
#
#        message(STATUS "Got unresolved tokens when querrying \"${TOKEN}\"; UNRESOLVED_TOKENS=${UNRESOLVED_TOKENS}")
        
        # UNRESOLVED_TOKENS contains a list like this: "{compiler.path};{compiler.c.cmd}"
        # try to resolve all tokens and store resolutions in key-value variables 
        foreach(UNRESOLVED_TOKEN ${UNRESOLVED_TOKENS})
            # UNRESOLVED_TOKEN contains a value like this: "{compiler.path}"   
        
            # repare UNRESOLVED_TOKEN_MATCHER that will be used to resolve UNRESOLVED_TOKEN
            set(UNRESOLVED_TOKEN_MATCHER)
            string(REPLACE "{" "" UNRESOLVED_TOKEN_MATCHER ${UNRESOLVED_TOKEN})
            string(REPLACE "}" "" UNRESOLVED_TOKEN_MATCHER ${UNRESOLVED_TOKEN_MATCHER})
            # UNRESOLVED_TOKEN_MATCHER contains an entry list like this: "compiler.path="
            # which can be used as a MATCHER token when we call ourself revursively
            
            # resolve UNRESOLVED_TOKEN and store value in RESOLVED_TOKEN
            set(RESOLVED_TOKEN)
#
#            message(STATUS "recursively resolving \"${UNRESOLVED_TOKEN_MATCHER}\"")
            arduconfig_get_property_deep(RESOLVED_TOKEN "${UNRESOLVED_TOKEN_MATCHER}" ${CONFIG_FILE})
            
            # prepare RESOLVED_TOKEN_KEY that will be used to hold contents of RESOLVED_TOKEN
            set(RESOLVED_TOKEN_KEY)
            string(REPLACE "{" "RUNTIME_" RESOLVED_TOKEN_KEY ${UNRESOLVED_TOKEN})
            string(REPLACE "}" "" RESOLVED_TOKEN_KEY ${RESOLVED_TOKEN_KEY})
            # RESOLVED_TOKEN_KEY contains an entry name like this: "RUNTIME_compiler.path"
            # which can be used as a variable name that holds contents of RESOLVED_TOKEN
            
            # store resolved key-value pair
#
#            message(STATUS "Resolved! store <${RESOLVED_TOKEN}> in \"${RESOLVED_TOKEN_KEY}\"")
            set(${RESOLVED_TOKEN_KEY} ${RESOLVED_TOKEN})
            #list(APPEND ${RESOLVED_TOKENS} ${RESOLVED_TOKEN})
        endforeach()
        
        # fix all unresolved tokerns that were present in TEMP_VALUE
        foreach(UNRESOLVED_TOKEN ${UNRESOLVED_TOKENS})
            string(REPLACE "{" "" UNRESOLVED_TOKEN ${UNRESOLVED_TOKEN})
            string(REPLACE "}" "" UNRESOLVED_TOKEN ${UNRESOLVED_TOKEN})
        
            set(RESOLVED_KEY "RUNTIME_${UNRESOLVED_TOKEN}")
            
            if (NOT ${RESOLVED_KEY})
                # this can happen if config value was empty
                set(${RESOLVED_KEY} " ")
            endif()
            
#
#            message(STATUS "Fixing \"${UNRESOLVED_TOKEN}\" with <${${RESOLVED_KEY}}> from \"${RESOLVED_KEY}\"")
            string(REPLACE "{${UNRESOLVED_TOKEN}}" ${${RESOLVED_KEY}} TEMP_VALUE ${TEMP_VALUE})
        endforeach()
    elseif()
        # everything is fine, no unresolved tokens
    endif() 

#
#    message(STATUS "Completed resolution for \"${TOKEN}\" with value <${TEMP_VALUE}>")
    set(${OUT_VAR_TO_SET} ${TEMP_VALUE} PARENT_SCOPE)
    set(RESOLVED_KEY "RUNTIME_${UNRESOLVED_TOKEN}" CACHE INTERNAL "")
endfunction()

###################################################################
function(arduconfig_get_property_shallows OUT_LIST_TO_APPEND MATCHER CONFIG_FILE)
# does not clear the list... hence appending, instead of replacing
#    set(${OUT_LIST_TO_APPEND} "" PARENT_SCOPE)

    if(EXISTS ${CONFIG_FILE})
        file(STRINGS ${CONFIG_FILE} FILE_ENTRIES)  # Settings file split into lines
#        message(STATUS "Config loading to ${OUT_LIST_TO_APPEND} from ${CONFIG_FILE}")
    
        foreach(FILE_ENTRY ${FILE_ENTRIES})
            if("${FILE_ENTRY}" MATCHES "${MATCHER}")
#                message(STATUS "Config really parsing ${FILE_ENTRY}")
                
                string(REGEX MATCH "^[^=]+" SETTING_NAME  ${FILE_ENTRY})
                string(REGEX MATCH "[^=]+$" SETTING_VALUE ${FILE_ENTRY})
                string(STRIP "${SETTING_VALUE}" SETTING_VALUE)
                
#                message(STATUS "Config parsed ${SETTING_NAME}  =  ${SETTING_VALUE}")

                # Save setting value
                list(APPEND ${OUT_LIST_TO_APPEND} ${SETTING_VALUE})
            endif()
        endforeach()
        set(${OUT_LIST_TO_APPEND} ${${OUT_LIST_TO_APPEND}} PARENT_SCOPE)
    else()
        message(FATAL_ERROR "This file does not exist: ${CONFIG_FILE}")
    endif()
endfunction()

###################################################################
function (arduconfig_export_ardu_variable OUT_VARIABLE TOKEN)
    arduconfig_get_property_deep(TMP_VALUE ${TOKEN} ${ARDU_PLATFORM_FILE})
    set(ARDU_${OUT_VARIABLE} "${TMP_VALUE}" CACHE INTERNAL "variable exported during arduconfig process" )
    
    message(STATUS "arduconfig; ARDU_${OUT_VARIABLE} = ${ARDU_${OUT_VARIABLE}}")
endfunction()

###################################################################
function (arduconfig_export_ardu_variable_compiler_bin OUT_VARIABLE TOKEN)
    arduconfig_get_property_deep(ARDU_TOOLCHAIN_BINARIES_PATH "compiler.path" ${ARDU_PLATFORM_FILE})

    arduconfig_get_property_deep(TMP_CMD ${TOKEN} ${ARDU_PLATFORM_FILE})
    set(ARDU_${OUT_VARIABLE} "${ARDU_TOOLCHAIN_BINARIES_PATH}${TMP_CMD}" CACHE INTERNAL "compiler binary exported during arduconfig process")

    # TODO provide argument that tells if we should be verbose instead of this workaround
    if (NOT "TEMP_PROP" STREQUAL "${OUT_VARIABLE}")
        message(STATUS "arduconfig; ARDU_${OUT_VARIABLE} = ${ARDU_${OUT_VARIABLE}}")
    endif()
endfunction()

###################################################################
function (arduconfig_set_property_from_other PROPERTY_NEW PROPERTY_OLD)
    arduconfig_export_ardu_variable(TEMP_PROP "${PROPERTY_OLD}")
    arduconfig_set_property(${PROPERTY_NEW} "${ARDU_TEMP_PROP}")
endfunction()

###################################################################
function (arduconfig_set_property OUT_RUNTIME_VARIABLE_PREFIX RUNTIME_VALUE)
    set(RUNTIME_${OUT_RUNTIME_VARIABLE_PREFIX} "${RUNTIME_VALUE}" CACHE FORCE "")
endfunction()
    

###################################################################
# This is where all the magic happens - Arduino platform configurations files are parsed
# and ARDU_* variables expected by the rest of Arduino build systems are available
# after this function completes
# 
# These variables are expected to be set when this function is run:
#
# - ARDU_PLATFORM_PATH - mandatory; points to directory where "platform.txt" file is
#     located
# - ARDU_RUNTIME_CONFIG_FILE - recommended; points to "runtime.txt" file that contains
#     chosen config
# 
# As a result, for example these ARDU_* variables will be set:
#
# - ARDU_BOARD_ID - depends on "build.board" properties from "runtime.txt"
#     e.g.: "uno", "mega" for AVR platforms, or "nodemcu" for ESP platform
# - ARDU_GCC_BINARY - depends on "compiler.c.cmd" and "compiler.path" properties from "platform.txt"
#     e.g.: "/some/path/1.20.0-26-gb404fb9-2/bin/xtensa-lx106-elf-gcc" for ESP platform\
# - ARDU_UPLOAD_SPEED - depends on "${ARDU_BOARD_ID}.upload.speed" property from "platform.txt"
#     e.g.: "115200" or "57600"
#
# Unfortunately there is a plethora of ARDU_* variables exported; mentioning them
# all is not possible. They are, however, clearly printed out when this function.
# Some more variables might be added in future, when 
#
function(arduconfig_init)
    if (ARDU_CONFIG_DONE)
        message(STATUS "arduconfig; already done, skipping}")
        return()
    endif()

    # silly attempt to have ARDU_RUNTIME_CONFIG_FILE guessed -- based on sane folders layout
    if (NOT EXISTS ${ARDU_RUNTIME_CONFIG_FILE}) 
        message(WARNING "arduconfig; ARDU_RUNTIME_CONFIG_FILE was not set explicitly -- guessing it")
        set(ARDU_RUNTIME_CONFIG_FILE "${CMAKE_CURRENT_LIST_DIR}/../../runtime.txt")
    endif()
    
    message(STATUS "arduconfig; ARDU_RUNTIME_CONFIG_FILE=${ARDU_RUNTIME_CONFIG_FILE}")

    # silly attempt to have ARDU_PLATFORM_PATH guessed -- based on ARDU_RUNTIME_CONFIG_FILE contents
    if (NOT IS_DIRECTORY ${ARDU_PLATFORM_PATH})
        message(WARNING "arduconfig; arduconfig was given wrong ARDU_PLATFORM_PATH -- guessing it")
       
        # find path to platform directory (one that contains platform.txt file) and
        # save it to ARDU_PLATFORM_PATH.
        # In order to work, one of the following should happen:
        # - ARDU_RUNTIME_CONFIG_FILE was provided and it contains "runtime.platform.path" entry
        # - RUNTIME_runtime_platform_path was provided
        arduconfig_get_property_deep(ARDU_PLATFORM_PATH "runtime.platform.path" ${ARDU_RUNTIME_CONFIG_FILE})
    endif()

    message(STATUS "arduconfig; ARDU_PLATFORM_PATH=${ARDU_PLATFORM_PATH}")
    
    # calculate platform.txt and it's RUNTIME_* variables cache
    set(ARDU_PLATFORM_FILE "${ARDU_PLATFORM_PATH}/platform.txt" CACHE INTERNAL "")
    message(STATUS "arduconfig; ARDU_PLATFORM_FILE = ${ARDU_PLATFORM_FILE}")
    arduconfig_cache_shallow_properties(${ARDU_PLATFORM_FILE})
       
    # calculate boards.txt and it's RUNTIME_* variables cache
    set(ARDU_BOARDS_FILE "${ARDU_PLATFORM_PATH}/boards.txt" CACHE INTERNAL "")
    message(STATUS "arduconfig; ARDU_BOARDS_FILE = ${ARDU_BOARDS_FILE}")
    arduconfig_cache_shallow_properties(${ARDU_BOARDS_FILE})
    
    # calculate programmers.txt and it's RUNTIME_* variables cache
    set(ARDU_PROGRAMMERS_FILE "${ARDU_PLATFORM_PATH}/programmers.txt" CACHE INTERNAL "")
    message(STATUS "arduconfig; ARDU_PROGRAMMERS_FILE = ${ARDU_PROGRAMMERS_FILE}")
    arduconfig_cache_shallow_properties(${ARDU_PROGRAMMERS_FILE})

    # this is needed to avoid us crashing while resolving some values
    set(RUNTIME_runtime.ide.version "666" CACHE INTERNAL "")

    # make sure ARDU_BOARD_ID is exported
    arduconfig_export_ardu_variable(BOARD_ID "build.board")
   
    # translate some of the ARDU_BOARD_ID dependant properties to generic ones
    # e.g.: value of "nodemcu.build.debug_level" will be used to provide "build.debug_level"
    arduconfig_set_property_from_other("build.flash_mode"   "${ARDU_BOARD_ID}.build.flash_mode")
    arduconfig_set_property_from_other("build.flash_freq"   "${ARDU_BOARD_ID}.build.flash_freq")
    arduconfig_set_property_from_other("build.flash_size"   "${ARDU_BOARD_ID}.build.flash_size")
    arduconfig_set_property_from_other("build.debug_port"   "${ARDU_BOARD_ID}.build.debug_port")
    arduconfig_set_property_from_other("build.debug_level"  "${ARDU_BOARD_ID}.build.debug_level")
    arduconfig_set_property_from_other("upload.resetmethod" "${ARDU_BOARD_ID}.upload.resetmethod")
    arduconfig_set_property_from_other("upload.speed"       "${ARDU_BOARD_ID}.upload.speed")
    
    # override some of the Arduino build system placeholders with cmake counterparts
    arduconfig_set_property("includes"           "<FLAGS>")
    arduconfig_set_property("source_file"        "<SOURCE>")
    arduconfig_set_property("object_file"        "<OBJECT>")
    arduconfig_set_property("object_files"       "<OBJECTS>")
    arduconfig_set_property("build.path"         "<CMAKE_CURRENT_BINARY_DIR>")
    arduconfig_set_property("build.project_name" "<TARGET>")

    # export ARDU_ veriables related to build setup
    arduconfig_export_ardu_variable(FLASH_MODE          "build.flash_mode")
    arduconfig_export_ardu_variable(FLASH_FREQ          "build.flash_freq")
    arduconfig_export_ardu_variable(FLASH_SIZE          "build.flash_size")
    arduconfig_export_ardu_variable(DEBUG_PORT          "build.debug_port")
    arduconfig_export_ardu_variable(DEBUG_LEVEL         "build.debug_level")
    arduconfig_export_ardu_variable(UPLOAD_RESET_METHOD "upload.resetmethod")
    arduconfig_export_ardu_variable(UPLOAD_SPEED        "upload.speed")

    # export ARDU_ veriables related to recipes
    arduconfig_export_ardu_variable(RECIPE_AR           "recipe.ar.pattern")
    arduconfig_export_ardu_variable(RECIPE_OBJ_C        "recipe.c.o.pattern")
    arduconfig_export_ardu_variable(RECIPE_OBJ_CXX      "recipe.cpp.o.pattern")
    arduconfig_export_ardu_variable(RECIPE_OBJ_ASM      "recipe.S.o.pattern")
    arduconfig_export_ardu_variable(RECIPE_LINK         "recipe.c.combine.pattern")
    arduconfig_export_ardu_variable(RECIPE_HEX          "recipe.objcopy.hex.pattern")
    arduconfig_export_ardu_variable(RECIPE_EEP          "recipe.objcopy.eep.pattern")
    arduconfig_export_ardu_variable(RECIPE_SIZE         "recipe.size.pattern")

    # export ARDU_ veriables related to compiler settings
    arduconfig_export_ardu_variable(GCC_FLAGS           "compiler.c.flags")
    arduconfig_export_ardu_variable(CXX_FLAGS           "compiler.cpp.flags")
    arduconfig_export_ardu_variable(ASM_FLAGS           "compiler.S.flags")
    arduconfig_export_ardu_variable(LINKER_FLAGS        "compiler.c.elf.flags")
    arduconfig_export_ardu_variable(LINKER_LIBS         "compiler.c.elf.libs")
    arduconfig_export_ardu_variable(PREPROCESSOR_FLAGS  "compiler.cpreprocessor.flags")

    # export ARDU_ veriables related to binaries
    arduconfig_export_ardu_variable_compiler_bin(GCC_BINARY         "compiler.c.cmd")
    arduconfig_export_ardu_variable_compiler_bin(CXX_BINARY         "compiler.cpp.cmd")
    arduconfig_export_ardu_variable_compiler_bin(ASM_BINARY         "compiler.S.cmd")
    arduconfig_export_ardu_variable_compiler_bin(LD_BINARY          "compiler.c.elf.cmd")
    arduconfig_export_ardu_variable_compiler_bin(SIZE_BINARY        "compiler.size.cmd")

    # makes sure that platform libraries are accessible for auto-linking
    link_directories("${ARDU_PLATFORM_PATH}/libraries/")
    
    set(ARDU_CONFIG_DONE true CACHE INTERNAL "indicates that autorun was already run and there is no need to do it again")
endfunction()
