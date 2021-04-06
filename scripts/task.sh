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
  local symphony_config_path=$3

  get_landingzone_path "$level" "$symphony_config_path"
  local lz_path=$(get_landingzone_path_by_name "$symphony_config_path" "$level")

  echo @"Running task: $task_name for level:$level"

}

