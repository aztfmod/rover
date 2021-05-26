## 2007.2408

NEW COMMANDS
* Launchpad commands moved into the rover with
```bash
rover -lz /tf/caf/landingzones/launchpad -a apply -launchpad
```

* Clone the public launchpad folder
```bash
# List all
rover --clone
```

* Clone the public landingzones folder (includes the launchpad)
```bash
# Clone the public open source landingzones from master branch
rover --clone-landingzones

# Clone the public open source landingzones from vnext branch
rover --clone-landingzones --clone-branch vnext
```

REMOVED COMMANDS
* launchpad.sh as now been replaced with
```
# Clone the launchpad with the new clone command
rover -lz launchpad_path -a plan -launchpad
```

# v2002 refresh

NOTES:

UPGRADE NOTES:

ENHANCEMENTS:
* Update terraform to 0.12.21
* Update az cli to 2.1.0
* Add kubectl v1.17.0
* Add Helm 3.1.0
* Adding launchpad_opensource_light. Add support for enable_collaboration

BUG FIXES:


# v2002.0320 (Monday February 3rd 2020)

NOTES:

UPGRADE NOTES:

ENHANCEMENTS:
* Rover login argument changes to rover login [tenant] [subscription]
* Deleting previous terraform.tfstate from rover after each execution
* terraform version to 0.12.20
* az cli version to 2.0.80
* git version to 2.25.0
* require sudo to execute docker in docker to access host docker deamon
* Adding bzip2
* Refactoring the Dockerfile to support multi-stage build and reduce sub-sequent rebuild

BUG FIXES:
* change *.sh from CRLF to LF
* moving docker-compose to /usr/bin
* fixing a curl for jq in the Dockerfile

NEW FEATURES:

# v1912.1312
UPGRADE NOTES:
* cleanup your vscode Dev Container volumes
docker volume rm -f $(docker volume ls -f label=caf)

ENHANCEMENTS:
* non-root support - requires vscode 1.41+

# v1912.1201

UPGRADE NOTES:
* terraform version to 0.12.18

ENHANCEMENTS:
* Removing terraform.tfstate from ~/.terrafom.cache after each terraform apply
* Aligning docker tags to git tags
* Renaming install.sh by build_image.sh

BUG FIXES:
* adding vscode user to docker group
