#!/bin/bash

# helper functions for working with symphony yaml file

function get_level {
  symphony_yaml_file=$1
  index=$2
  json=$(yq ".levels[${2}]" $1)

  echo $json
}

function get_level_count {
    yq '.levels | length' $1
}


function get_all_levels {
    echo  $(yq  -r -c '.levels[].level' $1)
}

function get_landing_zone_path {
  local task_config_file_path=$1
  local level=$2
  
}

