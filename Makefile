
default: github

github: 
	@bash "$(CURDIR)/scripts/build_image.sh" "github"

