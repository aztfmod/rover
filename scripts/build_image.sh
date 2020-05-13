#!/bin/bash

set -e
./scripts/pre_requisites.sh


case "$1" in 
    "github")
        tag=$(date +"%g%m.%d%H")
        rover="aztfmod/rover:${tag}"
        ;;
    "dev")
        tag=$(date +"%g%m.%d%H%M")
        rover="aztfmod/roverdev:${tag}"
        ;;
    *)
        tag=$(date +"%g%m.%d%H%M")
        rover="aztfmod/rover:${tag}"
        ;;
esac

echo "Creating version ${rover}"

# Build the rover base image
sudo docker-compose build --build-arg versionRover=${rover}


case "$1" in 
    "github")
        sudo docker tag rover_rover ${rover}
        sudo docker tag rover_rover aztfmod/rover:latest

        sudo docker push ${rover}
        sudo docker push aztfmod/rover:latest

        # tag the git branch and push
        git tag ${tag} master
        git push --follow-tags
        echo "Version aztfmod/rover:${tag} created."
        ;;
    "dev")
        sudo docker tag rover_rover ${rover}
        sudo docker tag rover_rover aztfmod/roverdev:latest

        sudo docker push ${rover}
        sudo docker push aztfmod/roverdev:latest
        echo "Version aztfmod/roverdev:${tag} created."
        echo "Version aztfmod/roverdev:latest created."
        ;;
    *)    
        sudo docker tag rover_rover aztfmod/rover:$tag
        sudo docker tag rover_rover aztfmod/rover:latest
        echo "Local version created"
        echo "Version aztfmod/rover:${tag} created."
        ;;
esac
