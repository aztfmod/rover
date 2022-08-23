#!/bin/bash

trap_with_arg() {
    func="$1" ; shift
    for sig; do
        trap "$func $sig" "$sig"
    done
}

function finally() 
{
  echo "Trapped: $1"
  trap - 0
  echo "Un-register the runner"
  ./config.sh remove --token ${AGENT_TOKEN}
}

trap_with_arg finally 0 1 2 3 4 5 6 7 8 9

AGENT_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
AGENT_NAME=${AGENT_NAME:="agent-${AGENT_SUFFIX}"}

if [ -n "${AGENT_TOKEN}" ]; then
  echo "Connect to GitHub using AGENT_TOKEN environment variable."
elif [ -n "${GH_TOKEN}" ]; then
  echo "Connect to GitHub using GH_TOKEN environment variable to retrieve registration token."
  AGENT_TOKEN=$(curl -sX POST -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GH_TOKEN}" https://api.github.com/repos/${GH_OWNER}/${REPOSITORY}/actions/runners/registration-token | jq -r .token)
elif [ -n "${KEYVAULT_NAME}" ]; then
  echo "Connect to Azure AD using MSI ${MSI_ID}"
  az login --identity -u ${MSI_ID} --allow-no-subscriptions
  # Get AGENT_TOKEN from KeyVault if not provided from the AGENT_TOKEN environment variable
  AGENT_TOKEN=$(az keyvault secret show -n ${KEYVAULT_SECRET} --vault-name ${KEYVAULT_NAME} -o json | jq -r .value)
else
  echo "You need to provide either AGENT_TOKEN, GH_TOKEN or (MSI_ID, KEYVAULT_NAME and KEYVAULT_SECRET) to start the self-hosted agent."
  exit 1
fi

LABELS+=",$(cat /tf/rover/version.txt)"

if [ -d "/var/run/docker.sock" ]; then
  # Grant access to the docker socket
  sudo chmod 666 /var/run/docker.sock
fi

echo "Configuring the agent with:"
echo " - url: ${URL}"
echo " - labels: ${LABELS}"
echo " - name: ${AGENT_NAME}"

command="./config.sh \
  --unattended \
  --disableupdate \
  --replace \
  --url ${URL}/${GH_OWNER}/${REPOSITORY} \
  --token ${AGENT_TOKEN} \
  --labels ${LABELS} \
  $(if [ "${EPHEMERAL}" = "true" ]; then
    echo "--ephemeral --name ${AGENT_NAME}"
  else
    echo "--name ${AGENT_NAME}"
  fi)"

echo "running command:" && echo $command


eval $command

./run.sh