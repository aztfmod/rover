#!/bin/bash

set -Ee

function finally {
  echo "Remove agent from agent pool $1"
  ./config.sh remove --unattended
}

trap finally EXIT SIGTERM SIGINT

if [ -n "${VSTS_AGENT_INPUT_TOKEN}" ]; then
  echo "Connect to Azure AD using PAT TOKEN from VSTS_AGENT_INPUT_TOKEN"
else
  echo "Connect to Azure AD using MSI ${MSI_ID}"
  az login --identity -u ${MSI_ID} --allow-no-subscriptions
  # Get PAT token from KeyVault if not provided from the AGENT_KEYVAULT_SECRET
  VSTS_AGENT_INPUT_TOKEN=$(az keyvault secret show -n ${AGENT_KEYVAULT_SECRET} --vault-name ${AGENT_KEYVAULT_NAME} -o json | jq -r .value)
fi

# Most of the variables are retrieved from VSTS_AGENT_INPUT_*
./config.sh --acceptTeeEula --replace --unattended && ./run.sh $VSTS_AGENT_INPUT_RUN_ARGS

