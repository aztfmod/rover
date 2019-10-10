
default: github

github: 
	docker build $$(./docker/buildargs.sh ./version.cat) -t rover \
		-f ./docker/github.Dockerfile ./docker

local: 
	cp ./.dockerignore ../.dockerignore
	docker build $$(./docker/buildargs.sh ./version.cat) -t rover \
		-f ./docker/local.Dockerfile ..

