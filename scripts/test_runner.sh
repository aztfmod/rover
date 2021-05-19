#!/usr/bin/env bash

function run_integration_tests {
  information @"Run Integration Tests"

  get_storage_id
  download_tfstate

  mv "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/$TF_VAR_tf_name" "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/terraform.tfstate"
  local prefix=$(find_and_export_prefix)
  export STATE_FILE_PATH="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
  
  debug "  Test Directory   : $base_directory"
  debug "  Environment      : $TF_VAR_environment"
  debug "  STATE_FILE_PATH  : $STATE_FILE_PATH"
  debug "  Level            : $TF_VAR_level"
  debug "  Prefix           : $prefix"
  
  export PREFIX=$prefix
  export ENVIRONMENT=$TF_VAR_environment
  export STATE_FILE_PATH="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
  
  cd $base_directory 
    pwd
    go test
  cd -
}

find_and_export_prefix () {
  rgName=$(az group list --query "[?tags.environment=='$TF_VAR_environment' && tags.landingzone].{Name:name}" | jq -r "first(.[].Name)")

  prefix=${rgName%-rg-launchpad*}

  echo $prefix
}

# rover test \
#       -b ~/projects/caf/symphony/tests \
#       -env one_week \
#       -level level0 \
#       -tfstate caf_launchpad.tfstate \
#       -d 