## 2001.dev (Unrelease)

NOTES:

UPGRADE NOTES:

ENHANCEMENTS:

BUG FIXES:

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
