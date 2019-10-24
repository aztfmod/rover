#!/bin/bash

git_mode=$1

echo ""
echo "setup the development environment"

set -e

setup_folder () {
    folder=$1
    if [ -d ${folder} ]; then
        echo "${folder} folder exists"
    else
        mkdir -p ${folder}
        echo "${folder} folder created"
    fi
}

clone () {

    name=$1
    ssh_url=$2
    clone_url=$3
    folder=$4
    git_clone_mode=$5

    echo ""
    echo "-----------------------------------------------"
    echo "name:            '${name}'"
    echo "ssh_url:         '${ssh_url}'"
    echo "clone_url:       '${clone_url}'"
    echo "folder:          '${folder}'"
    echo "git_clone_mode:  '${git_clone_mode}'"
    
    if [ ! -z $name ]; then
        echo "cloning:         '$name'"
        # Check if the folder already exist
        if [ ! -d "${folder}${name}" ]; then
            echo "cloning with ${git_clone_mode} - ${name} into ${folder}${name}"

            if [ ${git_clone_mode} == "gitssh" ]; then
                git clone $ssh_url ${folder}${name}
            else
                git clone $clone_url ${folder}${name}
            fi
        else
            echo "already cloned with ${git_clone_mode}"
            echo "pulling latest updates"
            git pull 
        fi
    fi
}

function clone_repos() {
    repo=$1
    folder=$2

    echo ${repo} | while read -d '" "' line; do
        if [ ! -z "${line}" ]; then
            clone ${line} ${folder} ${git_mode}
        fi
    done 
}

function clone_git {
    repo_patterns=(
        "aztfmod/landingzone_template"
        "aztfmod/landingzones"
        "aztfmod/level0"
        "aztfmod/blueprints"
    )

    repos=$(curl https://api.github.com/orgs/aztfmod/repos)

    # Clone modules
    setup_folder "../modules"
    repos_to_clone=$(echo $repos | jq '.[] | select(.full_name | contains("aztfmod/terraform-azurerm-caf-")) | "\(.name) \(.ssh_url) \(.clone_url)"')
    clone_repos "${repos_to_clone}" "../modules/"

    # Clone the repo_patterns
    for pattern in ${repo_patterns[@]}; do
        
        repos_to_clone=$(echo $repos | jq '.[] | select(.full_name | contains("'"${pattern}"'")) | "\(.name) \(.ssh_url) \(.clone_url)"')

        clone_repos "${repos_to_clone}" "../"

    done
}

function clone_azure_devops () {

    echo "cloning url: ${url}"
    echo "devops"

    target_folder="../private/"
    setup_folder "${target_folder}"
    clone "landingzones" "${url}" "" "${target_folder}" "gitssh"
}

if [ ${git_mode} == "gitssh" ] || [ ${git_mode} == "githttp" ]; then
    
    clone_git

else
    clone_azure_devops
fi



