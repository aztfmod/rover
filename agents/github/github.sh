#!/bin/bash

set -Ee

function finally {
  echo "Un-register the runner"
  ./config.sh remove --unattended
}

trap finally EXIT SIGTERM

AGENT_NAME=${AGENT_NAME:="agent"}

if [ -n "${AGENT_TOKEN}" ]; then
  echo "Connect to GitHub using AGENT_TOKEN environment variable."
else
  echo "Connect to Azure AD using MSI ${MSI_ID}"
  az login --identity -u ${MSI_ID} --allow-no-subscriptions
  # Get AGENT_TOKEN from KeyVault if not provided from the AGENT_TOKEN environment variable
  AGENT_TOKEN=$(az keyvault secret show -n ${KEYVAULT_SECRET} --vault-name ${KEYVAULT_NAME} -o json | jq -r .value)
fi

LABELS+="runner-version-$(./run.sh --version),"
LABELS+=$(cat /tf/rover/version.txt)

./config.sh \
  --unattended \
  --replace \
  --url ${URL} \
  --token ${AGENT_TOKEN} \
  --labels ${LABELS} \
  --name ${AGENT_NAME} \


./run.sh