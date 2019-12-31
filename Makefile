mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
name := $(subst docker-,,$(current_dir))

VERSION ?= $(shell git describe --always --tags)
REPO ?= qmxme
IMAGE ?= ${REPO}/${name}

BUILDX_VER=v0.3.1

buildx-install:
	mkdir -vp ~/.docker/cli-plugins/ ~/dockercache
	curl --silent -L "https://github.com/docker/buildx/releases/download/${BUILDX_VER}/buildx-${BUILDX_VER}.linux-amd64" > ~/.docker/cli-plugins/docker-buildx
	chmod a+x ~/.docker/cli-plugins/docker-buildx

buildx-prepare: buildx-install
	docker buildx create --use

buildx:
	docker buildx build --platform=linux/arm/v7,linux/amd64 -t ${IMAGE}:${VERSION} --load .

buildx-push:
	docker buildx build --platform=linux/arm/v7,linux/amd64 -t ${IMAGE}:${VERSION} --push .

build:
	docker build ${DOCKER_BUILD_OPTS} -t ${IMAGE}:${VERSION} .

build-nocache:
	docker build ${DOCKER_BUILD_OPTS} --no-cache -t ${IMAGE}:${VERSION} .

push: build
	docker push ${IMAGE}:${VERSION}

tag: build
	docker tag ${IMAGE}:${VERSION} ${IMAGE}:latest

push-tag: tag
	docker push ${IMAGE}:latest

beta: build
	docker tag ${IMAGE}:${VERSION} ${IMAGE}:beta

push-beta: beta
	docker push ${IMAGE}:beta

export: build
	docker export $$(docker create ${IMAGE}:${VERSION}) | gzip -9c > ${current_dir}-${VERSION}.tar.gz
