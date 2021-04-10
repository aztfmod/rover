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

  if [ ! -x "$(command -v $task_executable)" ]; then
    export code="1"
    error "1" "$task_executable is not installed!"
  fi

   if [ "$task_requires_init" == "true" ]; then
    export TF_VAR_tf_name=${TF_VAR_tf_name:="$(basename ${landing_zone_path}).tfstate"}
    expand_tfvars_folder "$config_path"
    tf_command=$(echo $PARAMS | sed -e 's/^[ \t]*//')
  fi

  echo " Running task        : $task_executable"
  echo " sub command         : $task_sub_command"
  echo " task init required  : $task_requires_init"
  echo " landing zone folder : $landing_zone_path"
  echo " config folder       : $config_path"
  echo " PARAMS              : $PARAMS"
  if [ "$task_executable" == "terraform" ] && [ "$task_requires_init" == "true" ]; then
    export tf_action="$task_sub_command"
    deploy ${TF_VAR_workspace}
  else
    task_executable=$(append $task_executable $task_sub_command)
    task_executable=$(append "$task_executable" "$task_flags")
    task_executable="$task_executable $(format_task_parameters "$task_parameters")"

    pushd "$landing_zone_path"  > /dev/null
      eval "$task_executable"
    popd > /dev/null
    echo " "
  fi
}

function get_task_by_name {
  local task_config_file=$1
  echo $(yq -r "." "$CI_TASK_DIR/$1.yml")
}

