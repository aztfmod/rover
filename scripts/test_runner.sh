#!/usr/bin/env bash

function run_integration_tests {
  information @"Run Integration Tests"

  if [ ! -x "$(command -v go)" ]; then
    error "go is not installed and is a required dependency to run integration tests."
  fi  

  if [[ ! -d $base_directory ]]; then
    error "Integration test path is invalid. $base_directory is not a valid path."
  fi  

  get_storage_id
  download_tfstate 

  local targetStateFile="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/terraform.tfstate"
  mv "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/$TF_VAR_tf_name" $targetStateFile
  local prefix=$(find_and_export_prefix)
  export STATE_FILE_PATH="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
  export PREFIX=$prefix
  export ENVIRONMENT=$TF_VAR_environment
  
  debug "  Test Directory   : $base_directory"
  debug "  Environment      : $ENVIRONMENT"
  debug "  STATE_FILE_PATH  : $STATE_FILE_PATH"
  debug "  STATE_FILE       : $targetStateFile"
  debug "  Level            : $TF_VAR_level"
  debug "  Prefix           : $PREFIX"
   
  pushd $base_directory > /dev/null
    go test -v -tags $TF_VAR_level
  popd > /dev/null

  debug "Removing $targetStateFile"
  rm $targetStateFile
}

find_and_export_prefix () {
  rgName=$(az group list --query "[?tags.environment=='$TF_VAR_environment' && tags.landingzone].{Name:name}" | jq -r "first(.[].Name)")

  prefix=${rgName%-rg-launchpad*}

  echo $prefix
}

rover test \
      -b /home/hattan/projects/caf/symphony/tests \
      -env one_week \
      -level level0 \
      -tfstate caf_launchpad.tfstate \
      -d 