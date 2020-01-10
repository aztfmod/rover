
default: github

github: 
	@bash "$(CURDIR)/scripts/build_image.sh" "github"

local:
	@bash "$(CURDIR)/scripts/build_image.sh" "local"


