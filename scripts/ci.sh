#!/bin/bash

source /tf/rover/task.sh
source /tf/rover/symphony_yaml.sh

declare -a CI_TASK_CONFIG_FILE_LIST=()
declare -a REGISTERED_CI_TASKS=()
declare CI_TASK_DIR=/tf/rover/ci_tasks/

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
    if [ -z "$symphony_yaml_file" ]; then
        export code="1"
        error "1" "Missing path to symphony.yml. Please provide a path to the file via -sc or --symphony-config"
        return $code
    fi

    if [ ! -f "$symphony_yaml_file" ]; then
        export code="1"
        error "1" "Invalid path, $symphony_yaml_file file not found. Please provide a valid path to the file via -sc or --symphony-config"
        return $code
    fi

    validate_symphony "$symphony_yaml_file"

    # verify ci task name is valid
    if [ ! -z "$ci_task_name" ]; then
        verify_task_name "$ci_task_name"
    fi
}

function set_default_parameters {
    echo "@Setting default parameters"
    export caf_command="landingzone"

    # export landingzone_name=<landing_zone_path>
    # export TF_VAR_tf_name=${TF_VAR_tf_name:="$(basename ${landingzone_name}).tfstate"}

    # export tf_action=<action name plan|apply|validate>
    # expand_tfvars_folder <var folder path>
    # deploy ${TF_VAR_workspace}
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
    echo "@Starting CI tools execution"

    if [ "${TF_VAR_level}" == "all" ]; then
      # get all levels from symphony yaml (only useful in env where there is a single MSI for all levels.)
      local -a levels=($(get_all_level_names "$symphony_yaml_file"))
      # echo "get all levels"
    else
      # run CI for a single level
      local -a levels=($(echo $TF_VAR_level))
      # echo "single level CI - ${TF_VAR_level}"
    fi

    for level in "${levels[@]}"
    do
        local -a stacks=($(get_all_stack_names_for_level "$symphony_yaml_file" "$level" ))

        if [ ${#stacks[@]} -eq 0 ]; then
          export code="1"
          error ${LINENO} "No stacks found, check that level ${level} exist and has stacks defined in ${symphony_yaml_file}"
        fi

        for stack in "${stacks[@]}"
        do
          landing_zone_path=$(get_landingzone_path_for_stack "$symphony_yaml_file" "$level" "$stack")
          config_path=$(get_config_path_for_stack "$symphony_yaml_file" "$level" "$stack")

          if [ ! -z "$ci_task_name" ]; then
            # run a single task by name
            run_task "$ci_task_name" "$level" "$landing_zone_path" "$config_path"
          else
            # run all tasks
            for task in "${REGISTERED_CI_TASKS[@]}"
            do
              run_task "$task" "$level" "$landing_zone_path" "$config_path"
            done
            echo " "
          fi
        done
    done

    success "All CI tasks have run successfully."
}

function clone_repos {
  echo @"Cloning repo ${1}"
  # TODO: We will start with git clone prior to CI execution.
}