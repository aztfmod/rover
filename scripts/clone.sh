#!/bin/bash

export clone_destination=${clone_destination:="/tf/caf/landingzones"}
export clone_folder=${clone_folder:="/"}
export clone_folder_strip=${clone_folder_strip:=2}
export clone_project_name=${clone_project_name:="Azure/caf-terraform-landingzones"}
export landingzone_branch=${landingzone_branch:="master"}

current_path=$(pwd)

function display_clone_instructions {

    while (("$#")); do
        case "${1}" in
            --intro)
                echo
                echo "Rover clone is used to bring the landing zones dependencies you need to deploy your landing zone"
                echo
                shift 1
                ;;
            --clone)
                display_clone_instructions --intro --examples --clone-branch --clone-destination --clone-folder --clone-folder-strip
                echo "--clone specify a GitHub organization and project in the for org/project"
                echo "      The default setting if not set is azure/caf-terraform-landingzones"
                echo
                shift 1
                ;;
            --clone-branch)
                echo "--clone-branch set the branch to pull the package."
                echo "      By default is not set use the master branch."
                echo
                shift 1
                ;;
            --clone-destination)
                echo "--clone-destination change the destination local folder."
                echo "      By default clone the package into the /tf/caf/landingzones folder of the rover"
                echo
                shift 1
                ;;
            --clone-folder)
                echo "--clone-folder specify the folder to extract from the original project"
                echo
                echo "      Example: --clone-folder /landingzones/landingzone_caf_foundations will only extract the caf foundations landing zone"
                echo
                shift 1
                ;;
            --clone-folder-strip)
                echo "--clone-folder-strip is used strip the base folder structure from the original folder"
                echo
                echo "      In the GitHub package of azure/caf-terraform-landingzones, the data are packaged in the following structure"
                echo "      caf-terraform-landingzones-master/landingzones/launchpad/main.tf"
                echo "      [project]-[branch]/landgingzones/[landingzone]"
                echo "      To reproduce a nice folder structure in the rover it it possible to set the --clone-folder-strip to 2 to remove [project]-[branch]/landingzones and only retrieve the third level folder"
                echo ""
                echo "      Default to 2 when using azure/caf-terraform-landingzones and 1 for all other git projects"
                echo
                shift 1
                ;;
            --clone-project-name)
                echo "--clone-project-name specify the GitHub repo to download from, default is Azure/caf-terraform-landingzones"
                echo
                echo "      Example: --clone-project-name Azure/caf-terraform-landingzones-starter --clone-branch starter will download the starter branch of the Azure/caf-terraform-landingzones-starter repo"
                echo "      Note: the default --cone-branch is master and this is not available in the example repo above so the starter branch is specified."
                echo
                shift 1
                ;;
            --examples)
                echo "By default the rover will clone the azure/caf-terraform-landingzones into the local rover folder /tf/caf/landinzones"
                echo
                echo "Examples:"
                echo "    - Clone the launchpad: rover --clone-folder /landingzones/launchpad"
                echo "    - Clone the launchpad in different folder: rover --clone-destination /tf/caf/landingzones/public --clone-folder /landingzones/launchpad"
                echo "    - Clone the launchpad (branch vnext): rover --clone-folder-strip 2 --clone-destination /tf/rover/landingzones --clone-folder /landingzones/launchpad --clone-branch vnext"
                echo
                echo "    - Clone the CAF foundations landingzone: rover --clone-folder /landingzones/landingzone_caf_foundations"
                echo "    - Clone the AKS landingzone: rover --clone aztfmod/landingzone_aks --clone-destination /tf/caf/landingzones/landingzone_aks"
                echo
                echo
                shift 1
                ;;
        esac
    done
}

function set_clone_exports {
    export clone_destination=$1
    export clone_folder=$2
    export clone_folder_strip=$3
    export clone_project_name=$4
    export landingzone_branch=$5
}

function clone_repository {
    echo "@calling clone_repository"

    url="https://codeload.github.com/${clone_project_name}/tar.gz/${landingzone_branch}"

    echo
    echo "clone_project_name    : ${clone_project_name}"
    echo "landingzone_branch    : ${landingzone_branch}"
    echo "clone_folder          : ${clone_folder}"
    echo "clone_folder_strip    : ${clone_folder_strip}"
    echo "clone_destination     : ${clone_destination}"
    echo "clone_url             : ${url}"
    echo ""

    rm -rf ${clone_destination}/$(basename ${clone_folder})
    mkdir -p ${clone_destination}

    curl https://codeload.github.com/${clone_project_name}/tar.gz/${landingzone_branch} --fail --silent --show-error | tar -zxv --strip=${clone_folder_strip} -C ${clone_destination} "$(basename ${clone_project_name})-${landingzone_branch}${clone_folder}"

    echo
    echo "Clone complete"
    echo
}

function process_clone_parameter {
    echo "@calling process_clone_parameter with $@"

    case "${1}" in
    --clone)
        if [ $# -eq 1 ]; then
            display_clone_instructions ${1}
            exit 21
        else
            export caf_command="clone"
            export landingzone_branch=${landingzone_branch:="master"}
            export clone_project_name=${2}
            export clone_folder_strip=1
        fi
        ;;
    --clone-branch)
        echo $#
        if [ $# -eq 1 ]; then
            display_clone_instructions ${1}
            exit 22
        else
            export landingzone_branch=${2}
        fi
        ;;
    --clone-destination)
        if [ $# -eq 1 ]; then
            display_clone_instructions ${1}
            exit 23
        else
            export clone_destination=${2}
        fi
        ;;
    --clone-folder)
        if [ $# -eq 1 ]; then
            display_clone_instructions ${1}
            exit 24
        else
            export clone_folder=${2}
        fi
        ;;
    --clone-folder-strip)
        if [ $# -eq 1 ]; then
            display_clone_instructions ${1}
            exit 24
        else
            export clone_folder_strip=${2}
        fi
        ;;
    --clone-project-name)
        if [ $# -eq 1 ]; then
            display_clone_instructions ${1}
            exit 24
        else
            export clone_project_name=${2}
        fi
        ;;
    esac
}
