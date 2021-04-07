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
    yq '.levels | length' $1
}


function get_all_level_names {
    echo  $(yq  -r -c '.levels[].level' $1)
}

function get_landingzone_path_by_name {
  local level=$1
  local symphony_config_path=$2
  yq  -r -c '.levels[]' $symphony_config_path
  get_landingzone_path "$level" "$symphony_config_path"
}

