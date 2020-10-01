#!/bin/bash

set -e
./scripts/pre_requisites.sh


case "$1" in 
    "github")
        tag=$(date +"%g%m.%d%H")
        rover="aztfmod/rover:${tag}"
        ;;
    "alpha")
        tag=$(date +"%g%m.%d%H%M")
        rover="aztfmod/roveralpha:${tag}"
        ;;
    "dev")
        tag=$(date +"%g%m.%d%H%M")
        rover="aztfmod/roverdev:${tag}"
        ;;
    "local")
        tag=$(date +"%g%m.%d%H%M")
        rover="roverlocal:${tag}"
        ;;
esac

echo "Creating version ${rover}"

# Build the rover base image
sudo docker-compose build --build-arg versionRover=${rover}


case "$1" in 
    "github")
        sudo docker tag rover_rover ${rover}
        sudo docker push ${rover}

        # tag the git branch and push
        git tag ${tag} master
        git push --follow-tags
        echo "Version aztfmod/rover:${tag} created."
        ;;
    "local")
        sudo docker tag rover_rover ${rover}
        echo "Version ${rover} created."
        ;;
    *)
        sudo docker tag rover_rover ${rover}
        sudo docker push ${rover}
        echo "Version ${rover} created."
        ;;
esac
