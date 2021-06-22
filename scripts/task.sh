#!/bin/bash

# helper functions for working with ci task config files

function get_list_of_task {
  local ci_task_dir=$1

  if [ ! -d "$ci_task_dir" ]; then

    export code="1"
    error "1" "Invalid CI Directory path, $ci_task_dir not found."
    return $code
  fi

  local -a files=()
  for file in "${ci_task_dir}*.yml"
  do
    files+=($file)
  done

  echo "${files[@]}"
}

function get_task_attribute {
  local task_config_file_path=$1
  local attribute_filter=$2

  yq -r ".${attribute_filter}" $1
}

function get_task_parameters_json {
  local task_config_file_path=$1

  yq -c ".parameters" $1
}

function get_task_name {
  local task_config_file_path=$1
  yq -r ".name" $1
}

function format_task_parameters {
  local task_parameters=$1
  local result=""
  for row in $(echo "${task_parameters}" | jq -r '.[] | @base64'); do
    local parameter=$(echo ${row} | base64 --decode)
    local name=$(echo ${parameter} | jq -r '.name')
    local value=$(echo ${parameter} | jq -r '.value')
    local prefix=$(echo ${parameter} | jq -r '.prefix')
    result="$foo $prefix$name=$value"
  done
  echo $result
}

function append {
  local string=$1
  local part=$2

  if [ ! -z "$part" ]; then
    echo "$string $part"
  else
    echo "$string"
  fi
}

function verify_local_tool_installed {
  local task_executable=$1
  if [ ! -x "$(command -v $task_executable)" ]; then
    export code="1"
    error "1" "$task_executable is not installed!"
  fi
}

function task_tf_init {
  local task_requires_init=$1
  local landing_zone_path=$2
  local config_path=$3
  local level=$4

  if [ "$task_requires_init" == "true" ]; then
    local state_file="$(basename ${landing_zone_path}).tfstate"
    local plan_file="$(basename ${landing_zone_path}).tfplan"
    export landingzone_name=$landing_zone_path
    export TF_VAR_tf_name=${state_file}
    export TF_VAR_tf_plan=${plan_file}
    export TF_VAR_level=${level}
    expand_tfvars_folder "$config_path"
    tf_command=$(echo $PARAMS | sed -e 's/^[ \t]*//')
  fi
}

function task_print_debug {
  local task_executable=$1
  local task_sub_command=$2
  local task_requires_init=$3
  local landing_zone_path=$4
  local config_path=$5
  local task_flags=$6
  local task_parameters=$7

  log_debug ""
  log_debug " Running task        : $task_executable"
  log_debug " sub command         : $task_sub_command"
  log_debug " task init required  : $task_requires_init"
  log_debug " landing zone folder : $landing_zone_path"
  log_debug " config folder       : $config_path"
  log_debug " flags               : $task_flags"
  log_debug " parameters          : $(format_task_parameters "$task_parameters")"
  log_debug " var files           : $PARAMS"
}

function run_task {
  local task_name=$1
  local level=$2
  local landing_zone_path=$3
  local config_path=$4

  local task_json=$(get_task_by_name "$task_name")
  local task_executable=$(echo $task_json | jq -r '.executableName')
  local task_sub_command=$(echo $task_json | jq -r '.subCommand')
  local task_flags=$(echo $task_json | jq -r '.flags')
  local task_parameters=$(echo $task_json | jq -r '.parameters')
  local task_requires_init=$(echo $task_json | jq -r '.requiresInit')

  unset PARAMS

  verify_local_tool_installed "$task_executable"
  task_tf_init "$task_requires_init" "$landing_zone_path" "$config_path" "$level"
  task_print_debug "$task_executable" "$task_sub_command" "$task_requires_init" "$landing_zone_path" "$config_path" "$task_flags" "$task_parameters"

  if [ "$task_executable" == "terraform" ] && [ "$task_requires_init" == "true" ]; then
     export tf_action="$task_sub_command"
    information "\n - running tool : $task_executable $task_sub_command"
    information "        lz path : $landing_zone_path"
    
    __set_text_log__ "$task_name"
    deploy ${TF_VAR_workspace}
    __reset_log__

  else
    run_non_terraform_tool "$task_executable" "$task_sub_command" "$task_requires_init" "$landing_zone_path" "$config_path" "$task_flags" "$task_parameters" "$task_name"
  fi
}

function run_non_terraform_tool {
  local task_executable=$1
  local task_sub_command=$2
  local task_requires_init=$3
  local landing_zone_path=$4
  local config_path=$5
  local task_flags=$6
  local task_parameters=$7
  local task_name=$8

  task_executable=$(append $task_executable $task_sub_command)
  task_executable=$(append "$task_executable" "$task_flags")
  task_executable="$task_executable $(format_task_parameters "$task_parameters")"

  pushd "$landing_zone_path"  > /dev/null
    information "\n - running tool : $task_executable"
    information "        lz path : $landing_zone_path"

    execute "$task_executable" "$task_name"
  popd > /dev/null
}

function execute {
  #mkdir -p /tf/logs/
  #local errFile=/tf/logs/$task_name.log
  #rm -rf $errFile

  #local task="$1 2>&1 | tee -a $errFile"
  local task=$1
  local task_name=$2
  local target_file=$3
  

  __set_text_log__ "$task_name"
  eval "$task"
  __reset_log__

  #if [ -s $errFile ]; then
  #  RETURN_CODE=3000
  #  error ${LINENO} "Error running ci task - $task_name" $RETURN_CODE
  #else
  #  success " - $task_name completed successfully with no issues."
  #fi
}

function get_task_by_name {
  local task_config_file=$1
  echo $(yq -r "." "$CI_TASK_DIR/$1.yml")
}

