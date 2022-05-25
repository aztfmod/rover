check_github_session() {
  debug "github"
  set -e
  url=$(git config --get remote.origin.url)
  export git_org_project=$(echo "$url" | sed -e 's#^https://github.com/##; s#^git@github.com:##; s#.git$##')
  export git_project=$(basename -s .git $(git config --get remote.origin.url))
  success "Connected to GiHub: repos/${git_org_project}"
  project=$(/usr/bin/gh api "repos/${git_org_project}" 2>/dev/null | jq -r .id)
  debug "${project}"
  /usr/bin/gh auth status
}

register_github_secret() {
  debug "@call register_github_secret for ${1}"

# ${1} secret name
# ${2} secret value

  /usr/bin/gh secret set "${1}" --body "${2}"

}