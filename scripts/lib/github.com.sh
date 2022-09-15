check_github_session() {
  information "@call check_github_session"
  url=$(git config --get remote.origin.url)
  export git_org_project=$(echo "$url" | sed -e 's#^https://github.com/##; s#^git@github.com:##; s#.git$##')
  export git_project=$(basename -s .git $(git config --get remote.origin.url))
  success "Connected to GiHub: repos/${git_org_project}"
  project=$(/usr/bin/gh api "repos/${git_org_project}" 2>/dev/null | jq -r .id)
  export GITOPS_SERVER_URL=$(/usr/bin/gh api "repos/${git_org_project}" 2>/dev/null | jq -r .svn_url)
  debug "${project}"
  
  verify_github_secret "actions" "BOOTSTRAP_TOKEN"

  if [ ! -v ${CODESPACES} ]; then
    verify_github_secret "codespaces" "GH_TOKEN"
  fi

  /usr/bin/gh auth status
}

verify_git_settings(){
  information "@call verify_git_settings for ${1}"

  command=${1}
  eval ${command}

  RETURN_CODE=$?
  if [ $RETURN_CODE != 0 ]; then
      error ${LINENO} "You need to set a value for ${command} before running the rover bootstrap." $RETURN_CODE
  fi
}

verify_github_secret() {
  information "@call verify_github_secret for ${1}/${2}"

  application=${1}
  secret_name=${2}

  /usr/bin/gh secret list -a ${application} | grep "${secret_name}"

  RETURN_CODE=$?

  echo "return code ${RETURN_CODE}"

  set -e
  if [ $RETURN_CODE != 0 ]; then
      error ${LINENO} "You need to set the ${application}/${secret_name} in your project as per instructions in the documentation." $RETURN_CODE
  fi
}

register_github_secret() {
  debug "@call register_github_secret for ${1}"

# ${1} secret name
# ${2} secret value

  /usr/bin/gh secret set "${1}" --body "${2}"

}