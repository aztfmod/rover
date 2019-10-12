

default: github

github: 
	@echo "loading landing zones from github"
	@echo ""

	docker build $$(./docker/buildargs.sh ./version.cat) -t rover \
		-f ./docker/github.Dockerfile ./docker

	@echo ""
	@echo "rover loaded with github landingzones"
	@echo "run ./rover.sh"

local:  
	@echo "loading landing zones from local folders"
	@echo ""
	
	cp ./.dockerignore ../.dockerignore
	docker build $$(./docker/buildargs.sh ./version.cat) -t rover \
		-f ./docker/local.Dockerfile ..

	@echo ""
	@echo "rover loaded with local landingzones"
	@echo "run ./rover.sh"

dev_modules:
	@sh "$(CURDIR)/scripts/setup_dev_environment.sh"

	