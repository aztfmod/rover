#!/usr/bin/env bash

__log_init__() {

    # Set Time zone to UTC / Comment out to use local time
    export TZ=UTC
  
    # map log level strings (FATAL, ERROR, etc.) to numeric values
    # Note the '-g' option passed to declare - it is essential
   
    unset _log_levels _loggers_level_map
    declare -gA _log_levels _loggers_level_map
    _log_levels=([FATAL]=0 [ERROR]=1 [WARN]=2 [INFO]=3 [DEBUG]=4 [VERBOSE]=5)
  
   
    # hash to map loggers to their log levels
    # the default logger "default" has INFO as its default log level
    _loggers_level_map["default"]=3  # the log level for the default logger is INFO

    #------------------------------------------------------------------------------
    # make sure log directory exists in standard log folder
    #------------------------------------------------------------------------------

    if [ -z "$log_folder_path" ]; then
        error "0" "Log folder path is not set" 1
    fi

    __create_dir__ "$log_folder_path"
   
}

__create_dir__()  {
    local path=$1
    mkdir -p $path
}

__set_text_log__() {
    local name=$1
    local logDate=$(date +%Y.%m.%d)

    if [ ! -d "$log_folder_path/$logDate" ]; then
      mkdir -p "$log_folder_path/$logDate"
    fi
    
    export LOG_TO_FILE=true
    export CURRENT_LOG_FILE="$log_folder_path/$logDate/$name.log"
    exec 3>&1 4>&2
    exec 1>> $CURRENT_LOG_FILE 2>&1
}

__reset_log__() {
    export LOG_TO_FILE=false
    unset CURRENT_LOG_FILE
    exec 2>&4 1>&3
}

#------------------------------------------------------------------------------
# set_log_severity
#------------------------------------------------------------------------------
set_log_severity() {
    local logger=default in_level l
    [[ $1 = "-l" ]] && { logger=$2; shift 2 2>/dev/null; }
    in_level="${1:-INFO}"
    
    if [[ $logger ]]; then
        l="${_log_levels[$in_level]}"
      
        if [[ $l ]]; then
            _loggers_level_map[$logger]=$l
           
        else
            printf '%(%Y-%m-%dT%H:%M:%S %Z)T %-7s %s ' -1 WARN \
                "${BASH_SOURCE[2]}:${BASH_LINENO[1]} Unknown log level '$in_level' for logger '$logger'; setting to INFO"
            _loggers_level_map[$logger]=3
        fi
    else
        printf '%(%Y-%m-%dT%H:%M:%S %Z)T %-7s %s ' -1 WARN \
            "${BASH_SOURCE[2]}:${BASH_LINENO[1]} Option '-l' needs an argument" >&2
    fi
}


_log() {
    local in_level=$1; shift
    local logger=default log_level_set log_level
   # [[ $1 = "-l" ]] && { logger=$2; shift 2; }
        
    log_level="${_log_levels[$in_level]}"
    log_level_set="${_loggers_level_map[$logger]}"

    if [[ $log_level_set ]]; then
         if [ "$log_level_set" -ge "$log_level" ]; then
            printf '%(%Y-%m-%dT%H:%M:%S %Z)T %-7s %s ' -1 "[$in_level]" "[${BASH_SOURCE[2]}:${BASH_LINENO[1]}]"
            printf '%s\n' "$@"
         fi
     else
         printf '%(%Y-%m-%dT%H:%M:%S %Z)T %-7s %s ' -1 [WARN] "[${BASH_SOURCE[2]}:${BASH_LINENO[1]}] Unknown logger '$logger'"
    fi
}


#------------------------------------------------------------------------------
# main logging functions
#------------------------------------------------------------------------------
log_fatal()   { _log FATAL   "$@"; }
log_error()   { _log ERROR   "$@"; }
log_warn()    { _log WARN    "$@"; }
log_info()    { _log INFO    "$@"; }
log_debug()   { _log DEBUG   "$@"; }
log_verbose() { _log VERBOSE "$@"; }

#------------------------------------------------------------------------------
# logging for function entry and exit
#------------------------------------------------------------------------------
log_info_enter()    { _log INFO    "Entering function ${FUNCNAME[1]}"; }
log_debug_enter()   { _log DEBUG   "Entering function ${FUNCNAME[1]}"; }
log_verbose_enter() { _log VERBOSE "Entering function ${FUNCNAME[1]}"; }
log_info_leave()    { _log INFO    "Leaving function ${FUNCNAME[1]}";  }
log_debug_leave()   { _log DEBUG   "Leaving function ${FUNCNAME[1]}";  }
log_verbose_leave() { _log VERBOSE "Leaving function ${FUNCNAME[1]}";  }

