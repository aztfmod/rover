#!/bin/bash

source ./task.sh
source ./symphony_yaml.sh

declare -a CI_TASK_CONFIG_FILE_LIST=()
declare -a REGISTERED_CI_TASKS=()
declare CI_TASK_DIR=./ci_tasks/
declare SYMPHONY_YAML_FILE="../public/caf_orchestrators/symphony-all.yml"

function verify_ci_parameters {
    echo "@Verifying ci parameters"
    # Hattan
    # verify symphony yaml file path
    # verify ci task configs
    # if running single task, verify that task name is valid
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
  for task in $REGISTERED_CI_TASKS
  do
    if [ $task eq $task_name ]; then
      return 1
    fi
  done
  return 0
}

function execute_ci_actions {
    echo "Executing CI action"
    # Richard
    # read levels
  local -a levels=()

  level_count=get_level_count $SYMPHONY_YAML_FILE

  for (( i=0; i < $level_count; i++))
  do
    levels+=()
  done

  # for each level
    # clone repos
    # execute tasks

}

function clone_repos {
  echo @"Cloning repo ${1}"
  # Richard
}