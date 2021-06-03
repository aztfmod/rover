#!/bin/bash

# helper functions for working with symphony yaml file

function get_integration_test_path {
  local symphony_yaml_file=$1

  integration_test_path=$(yq -r '.integrationTestsPath' $symphony_yaml_file)
  echo "$integration_test_path"
}


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

function get_state_file_name_for_stack {
  local symphony_yaml_file=$1
  local level_name=$2
  local stack_name=$3

  stateFileName=$(yq -r -c --arg level $level_name --arg stack $stack_name \
    '.levels[] | select(.level == $level) | .stacks[] | select (.stack == $stack) | .tfState' $symphony_yaml_file)

  echo $stateFileName
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

function validate_symphony {
  information "\n@ starting validation of symphony yaml. path: $symphony_yaml_file"
  local symphony_yaml_file=$1

  local -a levels=($(get_all_level_names "$symphony_yaml_file"))
  local -a results=()

  # for each level and each stack within the level
  #   Validate path exist for lz and config
  #   For stack config path, check at least 1 .tfvars exist
  #   For lz config path, check at least 1 .tf file exist
  local code=0

  for level in "${levels[@]}"
  do

    local -a stacks=($(get_all_stack_names_for_level "$symphony_yaml_file" "$level" ))
    for stack in "${stacks[@]}"
    do

      # test landing zone path
      test_lz=$(check_landing_zone_path_exists "$symphony_yaml_file" "$level" "$stack")

      if [ $test_lz == 'false' ]; then
        code=1
        error_message "  - error: Level '${level}' - Stack '$stack' has invalid landing zone path."
      fi

      # test configuration path
      test_config=$(check_configuration_path_exists "$symphony_yaml_file" "$level" "$stack")

      if [ $test_config == 'false' ]; then
        code=1
        error_message "  - error: Level '${level}' - Stack '$stack' has invalid configuration folder path."
      fi

      # test if tf files exist in landing zone
      test_lz_files=$(check_tf_exists "$symphony_yaml_file" "$level" "$stack")

      if [ $test_lz_files == 'false' ]; then
        code=1
        error_message "  - error: Level '${level}' - Stack '$stack', no .tf files found in landing zone."
      fi

      # test if tfvars files exist in configuration directory
      test_config_files=$(check_tfvars_exists "$symphony_yaml_file" "$level" "$stack")

      if [ $test_config_files == 'false' ]; then
        code=1
        error_message "  - error: Level '${level}' - Stack '$stack', no .tfvars files found in configuration folder."
      fi
    done
  done

  if [ "$code" != "0" ]; then
    echo ""
    error "" "$symphony_yaml_file contains invalid paths."
    return 1
  fi

  success "  All paths in $symphony_yaml_file are valid. \n"
  return 0

}

function check_landing_zone_path_exists {
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

  config_path=$(get_config_path_for_stack $symphony_yaml_file $level_name $stack_name)

  local files=(${config_path}*.tfvars)

  if [[ ${#files[@]} -gt 0 ]]; then
    echo true
    return
  fi

  echo false
}
function check_tf_exists {
  local symphony_yaml_file=$1
  local level_name=$2
  local stack_name=$3

  landing_zone_path=$(get_landingzone_path_for_stack "$symphony_yaml_file" "$level_name" "$stack_name")

  local files=(${landing_zone_path}*.tf)

  if [[ ${#files[@]} -gt 0 ]]; then
    echo true
    return
  fi

  echo false
}