# Building the rover agent for Github and testing locally

## Clone

Clone the rover repository

## Create a local build

```
make local
```

## Docker images

You can see the local images that have been created on your local machine

```
docker images
```

Example:

```
% docker images
REPOSITORY                         TAG                                            IMAGE ID       CREATED             SIZE
rover-agent                        1.3.0-alpha20220803-2208.170347-local-github   1e3d4de6a979   36 minutes ago      3.64GB
rover-agent                        1.3.0-alpha20220803-2208.170347-local-gitlab   4669d7c61fdb   37 minutes ago      3.36GB
rover-agent                        1.3.0-alpha20220803-2208.170347-local-tfc      9c4fe627e333   37 minutes ago      3.37GB
rover-agent                        1.1.9-2208.170347-local-gitlab                 83a90f49c291   38 minutes ago      3.37GB
rover-agent                        1.1.9-2208.170347-local-github                 494cf73b8e29   38 minutes ago      3.64GB
rover-agent                        1.1.9-2208.170347-local-tfc                    85c2971b0b03   38 minutes ago      3.37GB
rover-agent                        1.2.7-2208.170347-local-github                 cbb98046d631   39 minutes ago      3.64GB
rover-agent                        1.2.7-2208.170347-local-gitlab                 281d9383a8b0   39 minutes ago      3.36GB
rover-agent                        1.2.7-2208.170347-local-tfc                    7c7a0887ba83   39 minutes ago      3.37GB
localhost:5000/rover-local         1.3.0-alpha20220803-2208.170347                7c24fb68d69b   39 minutes ago      3.31GB
localhost:5000/rover-local         1.1.9-2208.170347                              01627897a3f2   39 minutes ago      3.32GB
localhost:5000/rover-local         1.2.7-2208.170347                              d75861cef748   40 minutes ago      3.31GB
localhost:5000/rover-local         1.3.0-alpha20220803-2208.170329                d8a0a368d9e5   58 minutes ago      3.31GB
localhost:5000/rover-local         1.1.9-2208.170329                              ba57a6d5fe51   58 minutes ago      3.32GB
localhost:5000/rover-local         1.2.7-2208.170329                              6bc9c449f8bc   58 minutes ago      3.31GB
```

## Create a PAT token

Under your Github profile, developer section, create a PAT token and give the following permissions:
- repo
- read:org

## Update docker-compose image and variables.env

docker-compose.yml
```yaml
---
version: '3.8'

services:
  rover-agent:
    image: rover-agent:1.2.7-2208.170347-local-github
    build:
      context: .
    env_file:
      - ./variables.env
```

variables.env
```yaml
GH_TOKEN=copy the value from the PAT token
GH_OWNER_REPOSITORY=owner/repo
URL=https://github.com/owner/repo
LABELS=platform
EPHEMERAL=true
```


Adjust the other variables

## Test the agent is working

```
cd agents/github/testing
docker-compose up
```

output:

```
% docker-compose up
[+] Running 1/0
 ⠿ Container testing-rover-agent-1  Recreated                                                                                                  0.1s
Attaching to testing-rover-agent-1
testing-rover-agent-1  | Connect to GitHub using GH_TOKEN environment variable to retrieve registration token.
testing-rover-agent-1  | Configuring the agent with:
testing-rover-agent-1  |  - url: https://github.com/LaurentLesle/a15
testing-rover-agent-1  |  - labels: test,runner-version-2.294.0
testing-rover-agent-1  | Runner listener exit with 0 return code, stop the service, no retry needed.
testing-rover-agent-1  | Exiting runner...,localhost:5000/rover-local:1.2.7-2208.170442
testing-rover-agent-1  |  - name: agent-2kasm
testing-rover-agent-1  | 
testing-rover-agent-1  | --------------------------------------------------------------------------------
testing-rover-agent-1  | |        ____ _ _   _   _       _          _        _   _                      |
testing-rover-agent-1  | |       / ___(_) |_| | | |_   _| |__      / \   ___| |_(_) ___  _ __  ___      |
testing-rover-agent-1  | |      | |  _| | __| |_| | | | | '_ \    / _ \ / __| __| |/ _ \| '_ \/ __|     |
testing-rover-agent-1  | |      | |_| | | |_|  _  | |_| | |_) |  / ___ \ (__| |_| | (_) | | | \__ \     |
testing-rover-agent-1  | |       \____|_|\__|_| |_|\__,_|_.__/  /_/   \_\___|\__|_|\___/|_| |_|___/     |
testing-rover-agent-1  | |                                                                              |
testing-rover-agent-1  | |                       Self-hosted runner registration                        |
testing-rover-agent-1  | |                                                                              |
testing-rover-agent-1  | --------------------------------------------------------------------------------
testing-rover-agent-1  | 
testing-rover-agent-1  | # Authentication
testing-rover-agent-1  | 
testing-rover-agent-1  | 
testing-rover-agent-1  | √ Connected to GitHub
testing-rover-agent-1  | 
testing-rover-agent-1  | # Runner Registration
testing-rover-agent-1  | 
testing-rover-agent-1  | 
testing-rover-agent-1  | 
testing-rover-agent-1  | 
testing-rover-agent-1  | √ Runner successfully added
testing-rover-agent-1  | √ Runner connection is good
testing-rover-agent-1  | 
testing-rover-agent-1  | # Runner settings
testing-rover-agent-1  | 
testing-rover-agent-1  | 
testing-rover-agent-1  | √ Settings Saved.
testing-rover-agent-1  | 
testing-rover-agent-1  | 
testing-rover-agent-1  | √ Connected to GitHub
testing-rover-agent-1  | 
testing-rover-agent-1  | Current runner version: '2.294.0'
testing-rover-agent-1  | 2022-08-16 20:55:23Z: Listening for Jobs
```

You can check the runner is running under the Github project runner section

From another terminal **docker-compose down** to clean up and de-register the container

```
docker-compose down 
```

## Test the agent is working in auto-scaling mode


```
docker-compose up --scale rover-agent=3 -d
```

output:

```
% docker-compose up --scale rover-agent=3 -d
[+] Running 3/3
 ⠿ Container testing-rover-agent-3  Started                                                                                                    0.5s
 ⠿ Container testing-rover-agent-1  Started                                                                                                    0.8s
 ⠿ Container testing-rover-agent-2  Started                                                                                                    0.8s
```

You can adjust the number of runners

```
docker-compose up --scale rover-agent=1 -d
```

## Stop all agents

```
% docker-compose down
```

```
% docker-compose down     
[+] Running 2/2
 ⠿ Container testing-rover-agent-1  Removed                                                                                                   10.3s
 ⠿ Network testing_default          Removed                                                                                                    0.3s
```