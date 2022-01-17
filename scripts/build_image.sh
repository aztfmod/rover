#!/usr/bin/env bash

error() {
    local parent_lineno="$1"
    local message="$2"
    local code="${3:-1}"
    local line_message=""
    if [ "$parent_lineno" != "" ]; then
        line_message="on or near line ${parent_lineno}"
    fi

    if [[ -n "$message" ]]; then
        echo >&2 -e "\e[41mError $line_message: ${message}; exiting with status ${code}\e[0m"
    else
        echo >&2 -e "\e[41mError $line_message; exiting with status ${code}\e[0m"
    fi
    echo ""

    cleanup

    exit ${code}
}

cleanup() {
    docker buildx rm rover || true
    docker rm --force registry_rover_tmp || true
}

set -ETe
trap 'error ${LINENO}' ERR 1 2 3 6

./scripts/pre_requisites.sh

params=$@
build_date=date
tag_date_preview=$(${build_date} +"%g%m.%d%H%M")
tag_date_release=$(${build_date} +"%g%m.%d%H")
export strategy=${1}

export DOCKER_CLIENT_TIMEOUT=600
export COMPOSE_HTTP_TIMEOUT=600

echo "params ${params}"
echo "date ${build_date}"

function build_base_rover_image {
    echo "params ${params}"
    versionTerraform=${1}
    strategy=${2}

    echo "@build_base_rover_image"
    echo "Building base image with:"
    echo " - versionTerraform - ${versionTerraform}"
    echo " - strategy                 - ${strategy}"

    echo "Terraform version - ${versionTerraform}"

    case "${strategy}" in
        "github")
            registry="aztfmod/"
            tag=${versionTerraform}-${tag_date_release}
            rover_base="${registry}rover"
            rover="${rover_base}:${tag}"
            export tag_strategy=""
            ;;
        "alpha")
            registry="aztfmod/"
            tag=${versionTerraform}-${tag_date_preview}
            rover_base="${registry}rover-alpha"
            rover="${rover_base}:${tag}"
            export tag_strategy="alpha-"
            ;;
        "dev")
            registry="aztfmod/"
            tag=${versionTerraform}-${tag_date_preview}
            rover_base="${registry}rover-preview"
            export rover="${rover_base}:${tag}"
            tag_strategy="preview-"
            ;;
        "ci")
            registry="symphonydev.azurecr.io/"
            tag=${versionTerraform}-${tag_date_preview}
            rover_base="${registry}rover-ci"
            export rover="${rover_base}:${tag}"
            tag_strategy="ci-"
            ;;
        "local")
            registry="localhost:5000/"
            tag=${versionTerraform}-${tag_date_preview}
            rover_base="${registry}rover-local"
            export rover="${rover_base}:${tag}"
            tag_strategy="local-"
            ;;
    esac

    echo "Creating version ${rover}"

    case "${strategy}" in
        "local")
            echo "Building rover locally"
            platform=$(uname -m)

            registry="${registry}" \
            versionRover="${rover_base}:${tag}" \
            versionTerraform=${versionTerraform} \
            tag="${tag}" \
            docker buildx bake \
                -f docker-bake.hcl \
                -f docker-bake.override.hcl \
                --set *.platform=linux/${platform} \
                --push rover_local
            ;;
        *)
            echo "Building rover image and pushing to Docker Hub"
            registry="${registry}" \
            versionRover="${rover_base}:${tag}" \
            versionTerraform=${versionTerraform} \
            tag="${tag}" \
            docker buildx bake \
                -f docker-bake.hcl \
                -f docker-bake.override.hcl \
                --set *.platform=linux/${platform} \
                --push rover_registry
            ;;
    esac

    echo "Image ${rover} created."


}

function build_rover_agents {
    # Build the rover agents and runners
    rover=${1}
    tag=${2}
    registry=${3}

    tag=${versionTerraform}-${tag_date_preview}

    echo "@build_rover_agents"
    echo "Building agents with:"
    echo " - registry      - ${registry}"
    echo " - version Rover - ${rover_base}:${tag}"
    echo " - tag           - ${tag}"
    echo " - strategy      - ${strategy}"
    echo " - tag_strategy  - ${tag_strategy}"

    case "${strategy}" in
        "local")

            registry="" \
            versionRover="${rover_base}:${tag}" \
            versionTerraform=${versionTerraform} \
            tag="${tag}" \
            docker buildx bake \
                -f docker-bake-agents.hcl \
                -f docker-bake.override.hcl \
                --load rover_agents
            ;;
        *)
            if [ "$strategy" == "ci" ]; then
                registry="${registry}" \
                versionRover="${rover_base}:${tag}" \
                versionTerraform=${versionTerraform} \
                tag="${tag}" \
                docker buildx bake \
                    -f docker-bake-agents.hcl \
                    -f docker-bake.override.hcl \
                    --push gitlab
            else
                registry="${registry}" \
                versionRover="${rover_base}:${tag}" \
                versionTerraform=${versionTerraform} \
                tag="${tag}" \
                docker buildx bake \
                    -f docker-bake-agents.hcl \
                    -f docker-bake.override.hcl \
                    --push rover_agents
            fi
            ;;
    esac

    echo "Agents created under tag ${registry}rover-agent:${tag}-${tag_strategy}github for registry '${registry}'"

}


docker buildx create --use --name rover --bootstrap --driver-opt network=host

case "${strategy}" in
    "local")
        # In memory docker registry required to store base image in local registry. This is due to buildkit docker-container not having access to docker host cache.
        docker run -d --name registry_rover_tmp --network=host registry:2 2>/dev/null || true
        ;;
esac

echo "Building rover images."
if [ "$strategy" == "ci" ]; then
    build_base_rover_image "1.0.0" ${strategy}
else
    while read versionTerraform; do
        build_base_rover_image ${versionTerraform} ${strategy}
    done <./.env.terraform

    while read versionTerraform; do
        build_rover_agents "${rover}" "${tag}" "${registry}"
    done <./.env.terraform
fi


case "${strategy}" in
    "local")
        docker rm --force registry_rover_tmp || true
        ;;
esac

docker buildx rm rover