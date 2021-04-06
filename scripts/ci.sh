#!/bin/bash

source /tf/rover/task.sh
source /tf/rover/symphony_yaml.sh

declare -a CI_TASK_CONFIG_FILE_LIST=()
declare -a REGISTERED_CI_TASKS=()
declare CI_TASK_DIR=/tf/rover/ci_tasks/
declare SYMPHONY_YAML_FILE="../public/caf_orchestrators/symphony-all.yml"




function verify_task_name(){
    local ci_task_name=$1
    local isTaskNameRegistered=$(task_is_registered "$ci_task_name")
    if [ "$isTaskNameRegistered" != "true" ]; then
        export code="1"
        error "1" "$ci_task_name is not a registered ci command!"
        return $code
    fi
}

function verify_ci_parameters {
    echo "@Verifying ci parameters"

    # verify symphony yaml
    if [ -z "$symphony_yml_path" ]; then
        export code="1"
        error "1" "Missing path to symphony.yml. Please provide a path to the file via -sc or--symphony-config"
        return $code
    fi

    if [ ! -f "$symphony_yml_path" ]; then
        export code="1"
        error "1" "Invalid path, $symphony_yml_path file not found. Please provide a valid path to the file via -sc or--symphony-config"
        return $code
    fi

    # verify ci task configs
    verify_task_name "terraform-format"
    verify_task_name "tflint"
    if [ ! -z "$ci_task_name" ]; then
        verify_task_name "$ci_task_name"
    fi
}

function set_default_parameters {
    echo "@Setting default parameters"
    # Hattan
    # TODO: Investigate if we need any of these for CI
}

function register_ci_tasks {
  echo @"Registering available ci task..."

  # Get List of config files
  CI_TASK_CONFIG_FILE_LIST=$(get_list_of_task ${CI_TASK_DIR})

  # For each config, grab the tool name
  # TODO: Eventually we will want to validate configs.  For now, we can assume if the yaml parses it is valid.
  for config in $CI_TASK_CONFIG_FILE_LIST
  do
    task_name=$(get_task_name ${config})
    echo @"Registered task... '${task_name}'"
    REGISTERED_CI_TASKS+=("${task_name}")
  done

}

function task_is_registered {
  local task_name=$1
  for task in "${REGISTERED_CI_TASKS[@]}"
  do
    if [ "$task" == "$task_name" ]; then
      echo "true"
      return
    fi
  done
  echo "false"
}

function execute_ci_actions {
    echo "Executing CI action"
    # Richard

    run_task "tflint" "level0" "$symphony_yml_path"

    local -a levels=($(get_all_level_names "$symphony_yml_path"))
    for level in "${levels[@]}"
    do
        # get stacks
        local -a stacks=($(get_all_stack_names_for_level "$symphony_yml_path" "$level" ))
        for stack in "${stacks[@]}"
        do
          # For each stack run ci tools
          landing_zone_path=$(get_landingzone_path_for_stack "$symphony_yml_path" "$level" "$stack")

          echo @"ci task execution - level: $level, stack: $stack at path: $landing_zone_path"
          run_task "tflint" "$level" "$symphony_yml_path"
        done

    done
}

function clone_repos {
  echo @"Cloning repo ${1}"
  # Richard
}