#!/bin/bash

# Required tools: jq, openssl, curl, az cli

if [ -n "${GITHUB_APP_KEYVAULT_NAME}" ]; then
  if [ -n "${MSI_ID}" ]; then
    echo "Connect to Azure AD using MSI ${MSI_ID}"
    az login --identity -u ${MSI_ID} --allow-no-subscriptions
  else
    echo "Connect to Azure AD using system assigned identity for the VM or Container App Environment"
    az login --identity --allow-no-subscriptions
  fi
  # Get AGENT_TOKEN from KeyVault if not provided from the AGENT_TOKEN environment variable
  GITHUB_APP_ID=$(az keyvault secret show -n ${GITHUB_APP_ID} --vault-name ${GITHUB_APP_KEYVAULT_NAME} -o json | jq -r .value)
  GITHUB_APP_PRIVATE_KEY=$(az keyvault secret show -n ${GITHUB_APP_PRIVATE_KEY} --vault-name ${GITHUB_APP_KEYVAULT_NAME} -o json | jq -r .value)
  GITHUB_APP_INSTALLATION_ID=$(az keyvault secret show -n ${GITHUB_APP_INSTALLATION_ID} --vault-name ${GITHUB_APP_KEYVAULT_NAME} -o json | jq -r .value)
fi

if [ -n "${GITHUB_APP_ID}" || -n "${GITHUB_APP_PRIVATE_KEY}" || -n "${GITHUB_APP_INSTALLATION_ID}" ]; then
  echo "You need to provide either GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY, GITHUB_APP_INSTALLATION_ID or (MSI_ID, GITHUB_APP_KEYVAULT_NAME) to get the GITHUB_APP_TOKEN"
  exit 1
fi

# Create payload for JWT
current_time=$(date +%s)
payload=$(jq -n \
    --arg iat_str "$current_time" \
    --arg exp_str $(($current_time + 600)) \
    --arg iss "${GITHUB_APP_ID}" \
    '{iat: ($iat_str | tonumber), exp: ($exp_str | tonumber), iss: $iss}')

# Create and sign JWT token with RS256 algorithm and private key
jwt_token=$(echo -n "$payload" | openssl dgst -binary -sha256 -sign <(echo -n "${GITHUB_APP_PRIVATE_KEY}") | openssl enc -base64 -A)

# Setup headers
headers="Authorization: Bearer $jwt_token"
headers="$headers Accept: application/vnd.github+json"
headers="$headers X-GitHub-Api-Version: 2022-11-28"

# Get access_token for installation
access_token_response=$(curl -s -X POST "https://api.github.com/app/installations/${GITHUB_APP_INSTALLATION_ID}/access_tokens" -H "$headers")
access_token=$(echo "$access_token_response" | jq -r .token)

# Check if access_token is obtained
if [ -z "$access_token" ]; then
    log_info "Failed to get access token."
    exit 1
fi

# Build Authorization header with access_token
headers="Authorization: Bearer $access_token"

# Get registration token for runner
api_endpoint="https://api.github.com/repos/${GH_OWNER}/${GH_REPOSITORY}/actions/runners/registration-token"
log_info "api_endpoint: $api_endpoint"
registration_token_response=$(curl -s -X POST "$api_endpoint" -H "$headers")
log_info "retrieving registration token endpoint: $(echo $registration_token_response | jq -r .status)"

# Return the registration token
registration_token=$(echo "$registration_token_response" | jq -r .token)
echo $registration_token


