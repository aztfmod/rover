#!/bin/bash


function verify_cd_parameters {
  echo "@Verifying cd parameters"
  
  case "${cd_action}" in
    run | apply | test)
      echo "Found valid cd action ${cd_action}"
    ;;
    *)
      error "invalid cd action: $cd_action. Possible values are (run, apply , test)"
  esac    

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
}


function join_path {
  local base_path=$1
  local part=$2

  if [[ "$base_path" != *'/' ]]; then
     base_path="$base_path/"
  fi

  if [[ "$part" == '/'* ]]; then
     part="${part:1}"
  fi  

  echo "$base_path$part"
}

# Convert AZURE_ENVIRONMENT to comply with autorest's expectations
# https://github.com/Azure/go-autorest/blob/master/autorest/azure/environments.go#L37
# To see az cli cloud names - az cloud list -o table
# We are only handling AzureCloud because the other cloud names are the same, only AzureCloud is different between az cli and autorest.
# Note the names below are camel case, Autorest converts all to upper case - https://github.com/Azure/go-autorest/blob/master/autorest/azure/environments.go#L263
function set_autorest_environment_variables {
  case $AZURE_ENVIRONMENT in
    AzureCloud)
    export AZURE_ENVIRONMENT='AzurePublicCloud'
    ;;
  esac
}

function process_cd_actions {
  echo "@Process cd actions"
  echo @"cd_action: $cd_action"

  execute_cd "$cd_action"
}

function execute_cd {
    local action=$1
    echo "@Starting CD execution"
    echo "@CD action: $action"

    if [ "${TF_VAR_level}" == "all" ]; then
      # get all levels from symphony yaml (only useful in env where there is a single MSI for all levels.)
      local -a levels=($(get_all_level_names "$symphony_yaml_file"))
      #echo "get all levels $levels"
    else
      # run CD for a single level
      local -a levels=($(echo $TF_VAR_level))
      #echo "single level CD - ${TF_VAR_level}"
    fi

    for level in "${levels[@]}"
    do
        if [ "$level" == "level0" ]; then
          export caf_command="launchpad"
        else
          export caf_command="landingzone"
        fi

        information "Deploying level: $level caf_command: $caf_command"
        
        local -a stacks=($(get_all_stack_names_for_level "$symphony_yaml_file" "$level" ))

        if [ ${#stacks[@]} -eq 0 ]; then
          export code="1"
          error ${LINENO} "No stacks found, check that level ${level} exist and has stacks defined in ${symphony_yaml_file}"
        fi

        for stack in "${stacks[@]}"
        do
          # Reset TFVAR file list
          PARAMS=""
          
          information "deploying stack $stack"
          join_path "$base_directory" "$integration_test_relative_path"

          landing_zone_path=$(get_landingzone_path_for_stack "$symphony_yaml_file" "$level" "$stack")
          config_path=$(get_config_path_for_stack "$symphony_yaml_file" "$level" "$stack")
          state_file_name=$(get_state_file_name_for_stack "$symphony_yaml_file" "$level" "$stack")
          integration_test_relative_path=$(get_integration_test_path "$symphony_yaml_file")
          integration_test_absolute_path=$(join_path "$base_directory" "$integration_test_relative_path")

          local plan_file="${state_file_name%.*}.tfplan"

          export landingzone_name=$landing_zone_path
          export TF_VAR_tf_name=${state_file_name}
          export TF_VAR_tf_plan=${plan_file}
          export TF_VAR_level=${level}
          expand_tfvars_folder "$config_path"
          tf_command=$(echo $PARAMS | sed -e 's/^[ \t]*//')                  
          export tf_action="apply"

          debug @"Starting Deployment"
          debug "                landingzone_name: $landingzone_name"
          debug "                  TF_VAR_tf_name: $TF_VAR_tf_name"
          debug "                  TF_VAR_tf_plan: $TF_VAR_tf_plan"
          debug "                    TF_VAR_level: $TF_VAR_level"
          debug "                       tf_action: $tf_action"          
          debug "                      tf_command: $tf_command"
          debug "                TF_VAR_workspace: $TF_VAR_workspace"
          debug "  integration_test_absolute_path: $integration_test_absolute_path"

         case "${action}" in
              run)
                  deploy "${TF_VAR_workspace}"
                  set_autorest_environment_variables
                  run_integration_tests "$integration_test_absolute_path"
                  ;;
              apply)
                  deploy "${TF_VAR_workspace}"
                  ;;
              test)
                  set_autorest_environment_variables
                  run_integration_tests "$integration_test_absolute_path"
                  ;;
              *)
                  error "invalid cd action: $action"
          esac          
        done
    done

    success "All levels deployed."
}

