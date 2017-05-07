

function(config_get_token OUT_VAR_TO_SET INPUT)
    # get setting name from input
    string(REGEX MATCH "^[^=]*" SETTING_NAME  ${INPUT})
    
    # get setting value from input
    string(REPLACE "${SETTING_NAME}=" ""  SETTING_VALUE ${INPUT})
    string(STRIP "${SETTING_VALUE}" SETTING_VALUE)
    
    # store setting name to output variable
    set(${OUT_VAR_TO_SET} "${SETTING_NAME}" PARENT_SCOPE)
endfunction()

function(config_get_tokens_from_file CONFIG_FILE)
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
                    set(RUNTIME_${SETTING_NAME} "${SETTING_VALUE}" CACHE INTERNAL "")
#                    message(STATUS "Cached \"RUNTIME_${SETTING_NAME}\" variable with <${SETTING_VALUE}> value")
                endif()
            endforeach()
        else()
            message(WARNING "Config file does not exist: ${CONFIG_FILE}")
        endif()
endfunction()

# looks up a TOKEN's value in the following locations:
# 1. among RUNTIME_* variables
# 2. in given CONFIG_FILE
# 3. in file pointed to by ARDU_RUNTIME_CONFIG_FILE variable
function(config_get_value OUT_VAR_TO_SET TOKEN CONFIG_FILE)
    set(MATCHER "${TOKEN}=")
    
    unset(SETTING_VALUE)
    
    set(RUNTIME_SETTING_VARIABLE "RUNTIME_${TOKEN}")
    
    if (${RUNTIME_SETTING_VARIABLE})
#        message(STATUS "Token \"${TOKEN}\" resolved with runtime variable \"${RUNTIME_SETTING_VARIABLE}\" = <${${RUNTIME_SETTING_VARIABLE}}>")
        set(SETTING_VALUE ${${RUNTIME_SETTING_VARIABLE}})
    else()
#        message(STATUS "Token \"${TOKEN}\" NOT resolved with runtime variable \"${RUNTIME_SETTING_VARIABLE}\"")
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
            config_get_value(SETTING_VALUE ${TOKEN} ${ARDU_RUNTIME_CONFIG_FILE})
        endif()
    endif()

    if (NOT SETTING_VALUE)
        message(FATAL_ERROR "Token \"${TOKEN}\" not found in ${CONFIG_FILE}, please provide <${RUNTIME_SETTING_VARIABLE}> variable or add \"${TOKEN}=\" entry to ARDU_RUNTIME_CONFIG_FILE=${ARDU_RUNTIME_CONFIG_FILE}")
    endif()

    # push returned value to the caller's scope
    set(${OUT_VAR_TO_SET} "${SETTING_VALUE}" PARENT_SCOPE)

endfunction()

function(config_get_value_resolved OUT_VAR_TO_SET TOKEN CONFIG_FILE )
    set(TEMP_VALUE "UNRESOLVED_${TOKEN}_ENTRY")
    config_get_value(TEMP_VALUE ${TOKEN} ${CONFIG_FILE})

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
            config_get_value_resolved(RESOLVED_TOKEN "${UNRESOLVED_TOKEN_MATCHER}" ${CONFIG_FILE})
            
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

function(config_get_values OUT_LIST_TO_APPEND MATCHER CONFIG_FILE)
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

function (ardu_config_export_value OUT_VARIABLE TOKEN)
    config_get_value_resolved(TMP_VALUE ${TOKEN} ${ARDU_PLATFORM_FILE})
    set(${OUT_VARIABLE} "${TMP_VALUE}" CACHE INTERNAL "variable exported during ardu_config process" )
    
   message(STATUS "ardu_config; ${OUT_VARIABLE} = ${${OUT_VARIABLE}}")
endfunction()

function (ardu_config_export_binary OUT_VARIABLE TOKEN)
    config_get_value_resolved(ARDU_TOOLCHAIN_BINARIES_PATH "compiler.path" ${ARDU_PLATFORM_FILE})

    config_get_value_resolved(TMP_CMD ${TOKEN} ${ARDU_PLATFORM_FILE})
    set(${OUT_VARIABLE} "${ARDU_TOOLCHAIN_BINARIES_PATH}${TMP_CMD}" CACHE INTERNAL "compiler binary exported during ardu_config process")

    message(STATUS "ardu_config; binary; ${OUT_VARIABLE} = ${${OUT_VARIABLE}}")
endfunction()

function(ardu_config)
    if (ARDU_CONFIG_DONE)
        message(STATUS "ardu_config; already done, skipping}")
        return()
    endif()

    # silly attempt to have ARDU_RUNTIME_CONFIG_FILE guessed -- based on sane folders layout
    if (NOT EXISTS ${ARDU_RUNTIME_CONFIG_FILE}) 
        message(WARNING "ardu_config; ARDU_RUNTIME_CONFIG_FILE was not set explicitly -- guessing it")
        set(ARDU_RUNTIME_CONFIG_FILE "${CMAKE_CURRENT_LIST_DIR}/../../runtime.txt")
    endif()
    
    message(STATUS "ardu_config; ARDU_RUNTIME_CONFIG_FILE=${ARDU_RUNTIME_CONFIG_FILE}")

    # silly attempt to have ARDU_PLATFORM_PATH guessed -- based on ARDU_RUNTIME_CONFIG_FILE contents
    if (NOT IS_DIRECTORY ${ARDU_PLATFORM_PATH})
        message(WARNING "ardu_config; ardu_config was given wrong ARDU_PLATFORM_PATH -- guessing it")
       
        # find path to platform directory (one that contains platform.txt file) and
        # save it to ARDU_PLATFORM_PATH.
        # In order to work, one of the following should happen:
        # - ARDU_RUNTIME_CONFIG_FILE was provided and it contains "runtime.platform.path" entry
        # - RUNTIME_runtime_platform_path was provided
        config_get_value_resolved(ARDU_PLATFORM_PATH "runtime.platform.path" ${ARDU_RUNTIME_CONFIG_FILE})
    endif()

    message(STATUS "ardu_config; ARDU_PLATFORM_PATH=${ARDU_PLATFORM_PATH}")
    
    # calculate platform.txt and it's RUNTIME_* variables cache
    set(ARDU_PLATFORM_FILE "${ARDU_PLATFORM_PATH}/platform.txt" CACHE INTERNAL "")
    message(STATUS "ardu_config; ARDU_PLATFORM_FILE = ${ARDU_PLATFORM_FILE}")
    config_get_tokens_from_file(${ARDU_PLATFORM_FILE})
       
    # calculate boards.txt and it's RUNTIME_* variables cache
    set(ARDU_BOARDS_FILE "${ARDU_PLATFORM_PATH}/boards.txt" CACHE INTERNAL "")
    message(STATUS "ardu_config; ARDU_BOARDS_FILE = ${ARDU_BOARDS_FILE}")
    config_get_tokens_from_file(${ARDU_BOARDS_FILE})
    
    # calculate programmers.txt and it's RUNTIME_* variables cache
    set(ARDU_PROGRAMMERS_FILE "${ARDU_PLATFORM_PATH}/programmers.txt" CACHE INTERNAL "")
    message(STATUS "ardu_config; ARDU_PROGRAMMERS_FILE = ${ARDU_PROGRAMMERS_FILE}")
    config_get_tokens_from_file(${ARDU_PROGRAMMERS_FILE})

    # this is needed to avoid us crashing while resolving some values
    set(RUNTIME_runtime.ide.version "666" CACHE INTERNAL "")

    # make sure ARDU_BOARD_ID is exported
    ardu_config_export_value(ARDU_BOARD_ID "build.board")

    # potentially user-configurable
    ardu_config_export_value(ARDU_FLASH_MODE "${ARDU_BOARD_ID}.build.flash_mode")
    set(RUNTIME_build.flash_mode "${ARDU_FLASH_MODE}" CACHE INTERNAL "")
    # potentially user-configurable    
    ardu_config_export_value(ARDU_FLASH_FREQ "${ARDU_BOARD_ID}.build.flash_freq")
    set(RUNTIME_build.flash_freq "${ARDU_FLASH_FREQ}" CACHE INTERNAL "")
    # potentially user-configurable    
    ardu_config_export_value(ARDU_FLASH_SIZE "${ARDU_BOARD_ID}.build.flash_size")
    set(RUNTIME_build.flash_size "${ARDU_FLASH_SIZE}" CACHE INTERNAL "")
    # potentially user-configurable    
    ardu_config_export_value(ARDU_UPLOAD_RESET_METHOD "${ARDU_BOARD_ID}.upload.resetmethod")
    set(RUNTIME_upload.resetmethod "${ARDU_UPLOAD_RESET_METHOD}" CACHE INTERNAL "")
    # potentially user-configurable    
    ardu_config_export_value(ARDU_UPLOAD_SPEED "${ARDU_BOARD_ID}.upload.speed")
    set(RUNTIME_upload.speed "${ARDU_UPLOAD_SPEED}" CACHE INTERNAL "")

    # override some of the Arduino build system placeholders with cmake counterparts
    set(RUNTIME_includes "<FLAGS>" CACHE FORCE "")
    set(RUNTIME_source_file "<SOURCE>" CACHE FORCE "")
    set(RUNTIME_object_file "<OBJECT>" CACHE FORCE "")
    set(RUNTIME_object_files "<OBJECTS>" CACHE FORCE "")
    set(RUNTIME_build.path "<CMAKE_CURRENT_BINARY_DIR>" CACHE FORCE "")
    set(RUNTIME_build.project_name "<TARGET>" CACHE FORCE "")
       
    ardu_config_export_value(ARDU_RECIPE_AR "recipe.ar.pattern")
    ardu_config_export_value(ARDU_RECIPE_OBJ_C "recipe.c.o.pattern")
    ardu_config_export_value(ARDU_RECIPE_OBJ_CXX "recipe.cpp.o.pattern")
    ardu_config_export_value(ARDU_RECIPE_OBJ_ASM "recipe.S.o.pattern")
    ardu_config_export_value(ARDU_RECIPE_LINK "recipe.c.combine.pattern")
    ardu_config_export_value(ARDU_RECIPE_HEX "recipe.objcopy.hex.pattern")
    ardu_config_export_value(ARDU_RECIPE_EEP "recipe.objcopy.eep.pattern")
    ardu_config_export_value(ARDU_RECIPE_SIZE "recipe.size.pattern")
    
    ardu_config_export_value(ARDU_GCC_FLAGS "compiler.c.flags")
    ardu_config_export_value(ARDU_CXX_FLAGS "compiler.cpp.flags")
    ardu_config_export_value(ARDU_ASM_FLAGS "compiler.S.flags")
    ardu_config_export_value(ARDU_LINKER_FLAGS "compiler.c.elf.flags")
    ardu_config_export_value(ARDU_LINKER_LIBS "compiler.c.elf.libs")
    ardu_config_export_value(ARDU_PREPROCESSOR_FLAGS "compiler.cpreprocessor.flags")

    ardu_config_export_binary(ARDU_GCC_BINARY "compiler.c.cmd")
    ardu_config_export_binary(ARDU_CXX_BINARY "compiler.cpp.cmd")
    ardu_config_export_binary(ARDU_ASM_BINARY "compiler.S.cmd")
    ardu_config_export_binary(ARDU_LD_BINARY "compiler.c.elf.cmd")
    ardu_config_export_binary(ARDU_SIZE_BINARY "compiler.size.cmd")
    
    set(ARDU_CONFIG_DONE true CACHE INTERNAL "indicates that autorun was already run and there is no need to do it again")
endfunction()



