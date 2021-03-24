# Updating the Dev Container

The dev container in this repo uses docker compose and an image hosted on dockerhub (aztfmod/rover:tag).

If you would like to make changes to the base image used by the dev container, you need to build the image then update the docker-compose.yml file to point to the newly created local image.

## 1) Build the local image

* Modify [Dockerfile](../Dockerfile) with the desired changed.
* From the root of the repository execute `make dev`
* The script should build a local image, but fail to push to DockerHub (since aztfmod/rover requires credentials a docker login.) . This isn't a problem, as we can modify your local set up to use a local image, rather than one on DockerHub.
* In the build log note the line with the updated image name and tag. It will be something along the lines of

  ```shell
  Pushing rover_registry (aztfmod/rover-preview:0.13.6-2103.211716)...
  ```

## 2) Update the Docker Compose File

* Copy the name and tag in parenthesis (in this case aztfmod/rover-preview:0.13.6-2103.211716)
* Open [.devcontainer/docker-compose.yml](../.devcontainer/docker-compose.yml) and update the image property to the value from the log (note your version will be different from below).

  In addition, bump the version number after the decimal point. (eg. 3.7 -> 3.8)

  ```yaml
  version: '3.8'
  services:
    rover:
      image: rover-preview:0.13.6-2103.211716
  ```

## 3) Delete the rover volume.

If you have previously launched the devconatiner, your home folder will be mapped to a docker volume. This will ovewrite any changes made to the home folder in the Dockerfile. As such, if you need to update the home folder in the dev container, then you need to delete the rover volume.

* Check the local docker volume
  `docker volume ls`

* Look for a volume named `rover_devcontainer_volume-caf-vscode`

* Remove the dev container volume (WARNING: This will delete the home folder, please ensure there nothing there you want to keep. Otherwise, copy it somewhere else temporarily)

  ` docker volume rm rover_devcontainer_volume-caf-vscode`

* If an error appears that looks like this:

  ```shell
  Error response from daemon: remove rover_devcontainer_volume-caf-vscode: volume is in use - [528ecf0f993339e4f1b53082caf1dd81dc01e433f98fab98f7aac5a08a6c4fff]
  ```

  That indicates that the volume is being used by a container with the id specified. It's safe to remove that container as it will be recreated.

  ```shell
  docker rm -f 528ecf0f993339e4f1b53082caf1dd81dc01e433f98fab98f7aac5a08a6c4fff
  ```

## 4) Restart Dev Container.

* Open the repo in VS Code.
* Using the keyboard shortcut ctl-shit-p, select Rebuild and Reopen in Container.


