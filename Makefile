
default: github

github: 
	@bash "$(CURDIR)/scripts/install.sh" "github"

local:
	@bash "$(CURDIR)/scripts/install.sh" "local"

private:
	@bash "$(CURDIR)/scripts/install.sh" "private"


setup_dev_gitssh:
	@bash "$(CURDIR)/scripts/setup_dev_environment.sh" "gitssh"

setup_dev_githttp:
	@bash "$(CURDIR)/scripts/setup_dev_environment.sh" "githttp"

setup_dev_devops_ssh:
	@bash "$(CURDIR)/scripts/setup_dev_environment.sh" "devopsssh"