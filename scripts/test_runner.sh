#!/usr/bin/env bash

function run_integration_tests {
  information @"Run Integration Tests"
  local target_directory=$1

  if [ ! -x "$(command -v go)" ]; then
    error "go is not installed and is a required dependency to run integration tests."
  fi  

  if [[ ! -d $target_directory ]]; then
    error "Integration test path is invalid. $target_directory is not a valid path."
  fi  

  get_storage_id

  log_info "Downloading TFState for level $TF_VAR_level"
  __set_text_log__ "${TF_VAR_level}_tests"
  download_tfstate 
  __reset_log__

  local targetStateFile="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/terraform.tfstate"
  mv "${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}/$TF_VAR_tf_name" $targetStateFile
  local prefix=$(find_and_export_prefix)
  export STATE_FILE_PATH="${TF_DATA_DIR}/tfstates/${TF_VAR_level}/${TF_VAR_workspace}"
  export PREFIX=$prefix
  export ENVIRONMENT=$TF_VAR_environment
  export ARM_SUBSCRIPTION_ID=$(echo ${account} | jq -r .id)
  
  information  "Running tests for level $TF_VAR_level"
  log_debug "Test Directory   : $target_directory"
  log_debug "Environment      : $ENVIRONMENT"
  log_debug "Subscription Id  : $ARM_SUBSCRIPTION_ID"
  log_debug "STATE_FILE_PATH  : $STATE_FILE_PATH"
  log_debug "STATE_FILE       : $targetStateFile"
  log_debug "Level            : $TF_VAR_level"
  log_debug "Prefix           : $PREFIX"
   
  pushd $target_directory > /dev/null
    __set_text_log__ "${TF_VAR_level}_tests"
    local logFile=$CURRENT_LOG_FILE
    go test -v -tags $TF_VAR_level
    __reset_log__
    success "$TF_VAR_level tests passed, full log output $logFile"

  popd > /dev/null

  log_debug "Removing $targetStateFile"
  rm $targetStateFile
}

find_and_export_prefix () {
  rgName=$(az group list --query "[?tags.environment=='$TF_VAR_environment' && tags.landingzone].{Name:name}" | jq -r "first(.[].Name)")

  prefix=${rgName%-rg-launchpad*}

  echo $prefix
}

