#!/bin/bash

# helper functions for working with symphony yaml file

function get_level {
  symphony_yaml_file=$1
  index=$2

  json=$(yq ".levels[${2}]" $1)
  echo $json
}

function get_level_by_name {
  local symphony_yaml_file=$1
  local level=$2

  json=$(yq -r --arg level $level '.levels[] | select(.level == $level)' $symphony_yaml_file)
  echo $json
}

function get_level_count {
  local symphony_yaml_file=$1

  yq '.levels | length' $symphony_yaml_file
}


function get_all_level_names {
  local symphony_yaml_file=$1

  echo  $(yq  -r -c '.levels[].level' $symphony_yaml_file)
}

function get_landingzone_path_for_stack {
  local symphony_yaml_file=$1
  local level_name=$2
  local stack_name=$3

  relativePath=$(yq -r -c --arg level $level_name --arg stack $stack_name \
    '.levels[] | select(.level == $level) | .stacks[] | select (.stack == $stack) | .landingZonePath' $symphony_yaml_file)

  echo "${base_directory}/${relativePath}"
}

function get_config_path_for_stack {
  local symphony_yaml_file=$1
  local level_name=$2
  local stack_name=$3

  relativePath=$(yq -r -c --arg level $level_name --arg stack $stack_name \
    '.levels[] | select(.level == $level) | .stacks[] | select (.stack == $stack) | .configurationPath' $symphony_yaml_file)

  echo "${base_directory}/${relativePath}"
}

function get_all_stack_names_for_level {
    local symphony_yaml_file=$1
    level_name=$2

    echo $(yq -r -c --arg level $level_name '.levels[] | select(.level == $level) | .stacks[].stack' $symphony_yaml_file)
}

function get_stack_by_name_for_level {
  local symphony_yaml_file=$1
  local level_name=$2
  local stack_name=$3

  json=$(yq -r -c --arg level $level_name --arg stack $stack_name \
    '.levels[] | select(.level == $level) | .stacks[] | select (.stack == $stack)' $symphony_yaml_file)
  echo $json
}

function validate {
  local symphony_yaml_file=$1

  local -a levels=($(get_all_level_names "$symphony_yaml_file"))

  # for each level and each stack within the level
  #   Validate path exist for lz and config
  #   For stack config path, check at least 1 .tfvars exist
  #   For lz config path, check at least 1 .tf file exist

  for level in "${levels[@]}"
  do
    local -a stacks=($(get_all_stack_names_for_level "$symphony_yaml_file" "$level" ))
    for stack in "${stacks[@]}"
    do
      test=$(check_landing_zone_paths "$symphony_yaml_file" "$level" "$stack")

    done
  done


}

function check_landing_zone_paths {
  local symphony_yaml_file=$1
  local level_name=$2
  local stack_name=$3

  landing_zone_path=$(get_landingzone_path_for_stack "$symphony_yaml_file" "$level_name" "$stack_name")

  if [[ ! -d $landing_zone_path ]]; then
    # path does not exist
    echo false
    return
  fi

  # path exists
  echo true
}

function check_configuration_path_exists {
  local symphony_yaml_file=$1
  local level_name=$2
  local stack_name=$3

  config_path=$(get_config_path_for_stack $symphony_yaml_file $level_name $stack_name)

  if [[ ! -d $config_path ]]; then
    # path does not exist
    echo false
    return
  fi

  # path exists
  echo true

}

function check_tfvars_exists {
  local symphony_yaml_file=$1
  local level_name=$2
  local stack_name=$3
}
function check_tf_exists {
  local symphony_yaml_file=$1
  local level_name=$2
  local stack_name=$3
}