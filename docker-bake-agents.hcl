#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

#
# make is calling the ./scripts/build_images.sh who calls docker buildx bake
#

variable "registry" {
  default = ""
}

variable "tag" {
  default = ""
}

variable "versionRover" {
  default = ""
}

group "rover_agents" {
  targets = ["github","azdo", "tfc", "gitlab"]
}

target "github" {
  dockerfile = "./agents/github/Dockerfile"
  tags = ["${registry}rover-agent:${tag}-github"]
  args = {
    versionGithubRunner = versionGithubRunner
    versionRover        = versionRover
    USERNAME            = USERNAME
  }
  platforms = ["linux/amd64","linux/arm64"]
  cache-to = ["type=local,dest=/tmp/.buildx-cache,mode=max"]
  cache-from = ["type=local,src=/tmp/.buildx-cache"]
}

target "azdo" {
  dockerfile = "./agents/azure_devops/Dockerfile"
  tags = ["${registry}rover-agent:${tag}-azdo"]
  args = {
    versionAzdo = versionAzdo
    versionRover = versionRover
    USERNAME     = USERNAME
  }
  platforms = ["linux/amd64"]
  cache-to = ["type=local,dest=/tmp/.buildx-cache,mode=max"]
  cache-from = ["type=local,src=/tmp/.buildx-cache"]
}

target "tfc" {
  dockerfile = "./agents/tfc/Dockerfile"
  tags = ["${registry}rover-agent:${tag}-tfc"]
  args = {
    versionTfc = versionTfc
    versionRover = versionRover
    USERNAME     = USERNAME
  }
  platforms = ["linux/amd64" ]
  cache-to = ["type=local,dest=/tmp/.buildx-cache,mode=max"]
  cache-from = ["type=local,src=/tmp/.buildx-cache"]
}

target "gitlab" {
  dockerfile = "./agents/gitlab/Dockerfile"
  tags = ["${registry}rover-agent:${tag}-gitlab"]
  args = {
    versionRover = versionRover
    USERNAME     = USERNAME
  }
  platforms = ["linux/amd64" ]
  cache-to = ["type=local,dest=/tmp/.buildx-cache,mode=max"]
  cache-from = ["type=local,src=/tmp/.buildx-cache"]
}
