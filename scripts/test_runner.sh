#!/usr/bin/env bash

function get_test_file_name() {
  local name=$TF_VAR_level
  
  if [ ! -z "$stack_name" ]; then
    name="${name}_${stack_name}"
  fi
  echo $name
}

function create_junit_report {
  if [ ! -f ~/go/bin/go-junit-report ]; then     
    __reset_log__ 
    log_warn "go-junit-report not found. Will not generate a junit xml report for test." 
    log_warn "https://github.com/jstemmer/go-junit-report"
  else
    local fileName=$(get_test_file_name)
    local logFolder=$(get_log_folder)
    
    if [ ! -z "$CURRENT_LOG_FILE" ]; then
      cat $CURRENT_LOG_FILE | ~/go/bin/go-junit-report > "$logFolder/${fileName}_test_report.xml"
    fi
    __reset_log__
  fi  
}
function run_integration_tests {
  information @"Run Integration Tests"
  local target_directory=$1
  local fileName=$(get_test_file_name)

  if [ ! -x "$(command -v go)" ]; then
    error "go is not installed and is a required dependency to run integration tests."
  fi  

  if [[ ! -d $target_directory ]]; then
    error "Integration test path is invalid. $target_directory is not a valid path."
  fi  

  get_storage_id

  log_info "Downloading TFState for level $TF_VAR_level"
  __set_text_log__ "${fileName}_tests_download"
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
    __set_text_log__ "${fileName}_tests"
    log_debug "starting test run"
    local logFile=$CURRENT_LOG_FILE
    local logFolder=$(get_log_folder)
    go test -v -tags "$TF_VAR_level,$stack_name" 
    RETURN_CODE=${PIPESTATUS[0]} && echo "Terraform plan return code: ${RETURN_CODE}"

    create_junit_report

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

