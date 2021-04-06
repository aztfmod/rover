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

  echo $(yq -r -c --arg level $level_name --arg stack $stack_name \
    '.levels[] | select(.level == $level) | .stacks[] | select (.stack == $stack) | .landingZonePath' $symphony_yaml_file)
}

function get_config_path_for_stack {
  local symphony_yaml_file=$1
  local level_name=$2
  local stack_name=$3

  echo $(yq -r -c --arg level $level_name --arg stack $stack_name \
    '.levels[] | select(.level == $level) | .stacks[] | select (.stack == $stack) | .configurationPath' $symphony_yaml_file)
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