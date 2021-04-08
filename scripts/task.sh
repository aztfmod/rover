#!/bin/bash

# helper functions for working with ci task config files

function get_list_of_task {
  local ci_task_dir=$1

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

  yq ".parameters" $1
}

function get_task_name {
  local task_config_file_path=$1
  yq -r ".name" $1
}

function run_task {
  local task_name=$1
  local level=$2
  local landing_zone_path=$3
  local task_json=$(get_task_by_name "$task_name")
  local task_executable=$(echo $task_json | jq -r '.executableName')  
  local task_sub_command=$(echo $task_json | jq -r '.subCommand')  
  local task_flags=$(echo $task_json | jq -r '.flags')  
  local task_parameters=$(echo $task_json | jq -r '.parameters')  

  if [ ! -x "$(command -v $task_executable)" ]; then
    export code="1"
    error "1" "$task_executable is not installed!"
  fi

  task_executable="$task_executable $task_sub_command"
  task_executable="$task_executable $task_flags"
  echo $task_parameters
  pushd "$base_directory/$landing_zone_path"
    echo @"Running task: $task_executable for level:$level lz:$landing_zone_path"
    eval "$task_executable"
  popd
}

function get_task_by_name {
  local task_config_file=$1
  echo $(yq -r "." "$CI_TASK_DIR/$1.yml")
}

