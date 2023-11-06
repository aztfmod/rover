#!/bin/bash

if [[ -v ARM_CLIENT_SECRET ]]; then
  echo "Logging with the service principal secret flow. ($ARM_CLIENT_ID)"
  az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET -t $ARM_TENANT_ID --allow-no-subscriptions >/dev/null >&1
fi

if [[ -v MSI-RESOURCE-ID ]]; then
  echo "Logging with the user-assigned managed identity. ($MSI-RESOURCE-ID)"
  az login --identity -u $(MSI-RESOURCE-ID) -t $ARM_TENANT_ID --allow-no-subscriptions >/dev/null >&1
fi

if [[ -v ARM_SUBSCRIPTION_ID ] || [ -v SUBSCRIPTION_ID ]]; then
  ARM_SUBSCRIPTION_ID=${ARM_SUBSCRIPTION_ID:="$SUBSCRIPTION_ID"}
  echo "Set the subscription to $ARM_SUBSCRIPTION_ID."
  az account set -s $ARM_SUBSCRIPTION_ID
  az account show -o json | jq
fi
