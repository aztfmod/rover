Build all agents

```bash
sudo docker-compose build
```


Build Azure Devops agent

```bash
# From the rover devcontainer
sudo docker build -f ./Dockerfile.azdo -t rover-aci .
sudo docker tag rover-aci:latest aztfmod/roveralpha:azdo
sudo docker push aztfmod/roveralpha:azdo
```

Build the GitHub self-hosted runner

```bash
# From the rover devcontainer
sudo docker-compose build github

```

Build Hashicorp Terraform Cloud

```bash
# From the rover devcontainer
sudo docker build -f ./Dockerfile.tfc -t rover-aci .
sudo docker tag rover-aci:latest aztfmod/roveralpha:tfc
sudo docker push aztfmod/roveralpha:tfc
```