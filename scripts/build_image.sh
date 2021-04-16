#!/usr/bin/env bash

set -e
./scripts/pre_requisites.sh

params=$@
build_date=date
tag_date_preview=$(${build_date} +"%g%m.%d%H%M")
tag_date_release=$(${build_date} +"%g%m.%d%H")
export strategy=${1}

echo "params ${params}"
echo "date ${build_date}"

function build_base_rover_image {
    echo "params ${params}"
    versionTerraform=${1}
    strategy=${2}

    echo "@build_base_rover_image"
    echo "Building base image with:"
    echo " - regversionTerraformistry - ${versionTerraform}"
    echo " - strategy                 - ${strategy}"

    echo "Terraform version - ${versionTerraform}"

    case "${strategy}" in
        "github")
            registry="aztfmod/"
            tag=${versionTerraform}-${tag_date_release}
            rover="${registry}rover:${tag}"
            export tag_strategy=""
            ;;
        "alpha")
            registry="aztfmod/"
            tag=${versionTerraform}-${tag_date_preview}
            rover="${registry}rover-alpha:${tag}"
            export tag_strategy="alpha-"
            ;;
        "dev")
            registry="aztfmod/"
            tag=${versionTerraform}-${tag_date_preview}
            export rover="${registry}rover-preview:${tag}"
            tag_strategy="preview-"
            ;;
        "ci")
            registry="symphonydev.azurecr.io/"
            tag=${versionTerraform}-${tag_date_preview}
            export rover="${registry}rover-ci:${tag}"
            tag_strategy="ci-"
            ;;            
        "local")
            registry=""
            tag=${versionTerraform}-${tag_date_preview}
            export rover="${registry}rover-local:${tag}"
            tag_strategy="local-"
            ;;
    esac

    echo "Creating version ${registry}${rover}"

    # Build the rover base image
    sudo versionRover="${rover}" docker-compose build \
        --build-arg versionTerraform=${versionTerraform} \
        --build-arg versionRover="${rover}"


    case "${strategy}" in
        "local")
            ;;
        *)
            echo "Pushing rover image to the docker regsitry"
            sudo versionRover="${rover}" docker-compose push rover_registry
            ;;
    esac

    echo "Image ${rover} created."

    # echo "Building CI/CD images."
    build_rover_agents "${rover}" "${tag}" "${registry}"

}

function build_rover_agents {
    # Build de rover agents and runners
    rover=${1}
    tag=${2}
    registry=${3}

    echo "@build_rover_agents"
    echo "Building agents with:"
    echo " - registry      - ${registry}"
    echo " - version Rover - ${rover}"
    echo " - tag           - ${tag}"
    echo " - strategy      - ${strategy}"
    echo " - tag_strategy  - ${tag_strategy}"
    cd agents
    
    if [ "$strategy" == "ci" ]; then
        tag="${tag}" registry="${registry}" tag_strategy="${tag_strategy}" docker-compose build  \
            --build-arg versionRover="${rover}" gitlab
    else
        sudo tag="${tag}" registry="${registry}" tag_strategy="${tag_strategy}" docker-compose build \
            --build-arg versionRover="${rover}"         
    fi

        case "${strategy}" in
        "local")
            ;;
        *)
            if [ "$strategy" == "ci" ]; then
                sudo tag="${tag}" registry="${registry}" tag_strategy="${tag_strategy}" docker-compose push gitlab
            else
                sudo tag="${tag}" registry="${registry}" tag_strategy="${tag_strategy}" docker-compose push        
            fi                   
            ;;
    esac

    echo "Agents created under tag ${tag} for registry '${registry}'"
    cd ..

}

echo "Building rover images."
if [ "$strategy" == "ci" ]; then
    build_base_rover_image "0.13.6" ${strategy}
else
    while read versionTerraform; do
        build_base_rover_image ${versionTerraform} ${strategy}
    done <./.env.terraform          
fi

