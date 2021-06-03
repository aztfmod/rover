#!/bin/bash


function verify_cd_parameters {
  echo "@Verifying cd parameters"

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

# function execute_cd {
#   echo "@Starting cd execution"
#   if [ "${TF_VAR_level}" == "all" ]; then
#     echo "deploy all"
#   else
#     echo "deploy level ${TF_VAR_level}"

#     # local state_file="$(basename ${landing_zone_path}).tfstate"
#     # local plan_file="$(basename ${landing_zone_path}).tfplan"
#     # export landingzone_name=$landing_zone_path
#     # export TF_VAR_tf_name=${state_file}
#     # export TF_VAR_tf_plan=${plan_file}
#     # export TF_VAR_level=${level}
#     # expand_tfvars_folder "$config_path"
#   fi
# }

function execute_cd {
    echo "@Starting CD execution"

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
          landing_zone_path=$(get_landingzone_path_for_stack "$symphony_yaml_file" "$level" "$stack")
          config_path=$(get_config_path_for_stack "$symphony_yaml_file" "$level" "$stack")
          state_file_name=$(get_state_file_name_for_stack "$symphony_yaml_file" "$level" "$stack")
          
          local plan_file="${state_file_name%.*}.tfplan"

          export landingzone_name=$landing_zone_path
          export TF_VAR_tf_name=${state_file_name}
          export TF_VAR_tf_plan=${plan_file}
          export TF_VAR_level=${level}
          expand_tfvars_folder "$config_path"
          tf_command=$(echo $PARAMS | sed -e 's/^[ \t]*//')                  
          export tf_action="apply"

          debug @"Starting Deployment"
          debug "  landingzone_name: $landingzone_name"
          debug "  TF_VAR_tf_name: $TF_VAR_tf_name"
          debug "  TF_VAR_tf_plan: $TF_VAR_tf_plan"
          debug "  TF_VAR_level: $TF_VAR_level"
          debug "  tf_action: $tf_action"
          debug "  tf_command: $tf_command"

          deploy ${TF_VAR_workspace}          

        done
    done

    success "All levels deployed."
}