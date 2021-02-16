#!/bin/bash

set -Ee

function finally {
  echo "Remove agent from agent pool"
  ./config.sh remove --unattended
}

trap finally EXIT SIGTERM

if [ -n "${VSTS_AGENT_INPUT_TOKEN}" ]; then
  echo "Connect to Azure AD using PAT TOKEN from VSTS_AGENT_INPUT_TOKEN"
else
  echo "Connect to Azure AD using MSI ${MSI_ID}"
  az login --identity -u ${MSI_ID} --allow-no-subscriptions
  # Get PAT token from KeyVault if not provided from the VSTS_AGENT_INPUT_TOKEN
  VSTS_AGENT_INPUT_TOKEN=$(az keyvault secret show -n ${VSTS_AGENT_INPUT_SECRET} --vault-name ${VSTS_AGENT_KEYVAULT_NAME} -o json | jq -r .value)
fi

# Most of the variables are retrieved from VSTS_AGENT_INPUT_*
./config.sh --acceptTeeEula --replace --unattended && ./run.sh