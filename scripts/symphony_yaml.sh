#!/bin/bash

# helper functions for working with symphony yaml file

function get_level {
  symphony_yaml_file=$1
  index=$2
  json=$(yq ".levels[${2}]" $1)

  echo $json
}

function get_level_count {
    symphony_yaml_file=$1

    yq '.levels | length' $1
}
