# Copyright (c) 2020-2022, NVIDIA CORPORATION.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

DOCKER   ?= docker
# DOCKER: docker

MKDIR    ?= mkdir
# MKDIR: mkdir

DIST_DIR ?= $(CURDIR)/dist
# DIST_DIR: /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia/dist

include $(CURDIR)/versions.mk

ifeq ($(IMAGE_NAME),)
REGISTRY ?= nvidia
# REGISTRY: nvidia

IMAGE_NAME = $(REGISTRY)/k8s-device-plugin
# IMAGE_NAME: nvidia/k8s-device-plugin
endif

BUILDIMAGE_TAG ?= golang$(GOLANG_VERSION)
# BUILDIMAGE_TAG: golang1.20.2

BUILDIMAGE ?= $(IMAGE_NAME)-build:$(BUILDIMAGE_TAG)
# BUILDIMAGE: nvidia/k8s-device-plugin-build:golang1.20.2

EXAMPLES := $(patsubst ./examples/%/,%,$(sort $(dir $(wildcard ./examples/*/))))
# EXAMPLES:

EXAMPLE_TARGETS := $(patsubst %,example-%, $(EXAMPLES))
# EXAMPLE_TARGETS:

CMDS := $(patsubst ./cmd/%/,%,$(sort $(dir $(wildcard ./cmd/*/))))
# CMDS: config-manager nvidia-device-plugin

CMD_TARGETS := $(patsubst %,cmd-%, $(CMDS))
# CMD_TARGETS: cmd-config-manager cmd-nvidia-device-plugin

CHECK_TARGETS := assert-fmt vet lint ineffassign misspell
# CHECK_TARGETS: assert-fmt vet lint ineffassign misspell

MAKE_TARGETS := binaries build check fmt lint-internal test examples cmds coverage generate $(CHECK_TARGETS)
# MAKE_TARGETS: binaries build check fmt lint-internal test examples cmds coverage generate assert-fmt vet lint ineffassign misspell

TARGETS := $(MAKE_TARGETS) $(EXAMPLE_TARGETS) $(CMD_TARGETS)
# TARGETS: binaries build check fmt lint-internal test examples cmds coverage generate assert-fmt vet lint ineffassign misspell cmd-config-manager cmd-nvidia-device-plugin

DOCKER_TARGETS := $(patsubst %,docker-%, $(TARGETS))
# DOCKER_TARGETS: docker-binaries docker-build docker-check docker-fmt docker-lint-internal docker-test docker-examples docker-cmds docker-coverage docker-generate docker-assert-fmt docker-vet docker-lint docker-ineffassign docker-misspell docker-cmd-config-manager docker-cmd-nvidia-device-plugin

.PHONY: $(TARGETS) $(DOCKER_TARGETS)

ifeq ($(VERSION),)
CLI_VERSION = $(LIB_VERSION)$(if $(LIB_TAG),-$(LIB_TAG))
else
CLI_VERSION = $(VERSION)
endif
# CLI_VERSION: v0.14.0

CLI_VERSION_PACKAGE = github.com/NVIDIA/k8s-device-plugin/internal/info
# CLI_VERSION_PACKAGE: github.com/NVIDIA/k8s-device-plugin/internal/info

GOOS ?= linux
# GOOS: linux

binaries: cmds
# $ make -n --just-print binaries
# CGO_LDFLAGS_ALLOW='-Wl,--unresolved-symbols=ignore-in-object-files' GOOS=linux \
# 		go build -ldflags "-s -w -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.14.0"  github.com/NVIDIA/k8s-device-plugin/cmd/config-manager
# CGO_LDFLAGS_ALLOW='-Wl,--unresolved-symbols=ignore-in-object-files' GOOS=linux \
# 		go build -ldflags "-s -w -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.14.0"  github.com/NVIDIA/k8s-device-plugin/cmd/nvidia-device-plugin
# $

ifneq ($(PREFIX),)
cmd-%: COMMAND_BUILD_OPTIONS = -o $(PREFIX)/$(*)
endif
# COMMAND_BUILD_OPTIONS:

cmds: $(CMD_TARGETS)
# $ make -n --just-print cmds
# CGO_LDFLAGS_ALLOW='-Wl,--unresolved-symbols=ignore-in-object-files' GOOS=linux \
# 		go build -ldflags "-s -w -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.14.0"  github.com/NVIDIA/k8s-device-plugin/cmd/config-manager
# CGO_LDFLAGS_ALLOW='-Wl,--unresolved-symbols=ignore-in-object-files' GOOS=linux \
# 		go build -ldflags "-s -w -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.14.0"  github.com/NVIDIA/k8s-device-plugin/cmd/nvidia-device-plugin
# $

print:
	@echo "DOCKER: "$(DOCKER)
	@echo "MKDIR: "$(MKDIR)
	@echo "DIST_DIR: "$(DIST_DIR)
	@echo "MODULE: "$(MODULE)
	@echo "VERSION: "$(VERSION)
	@echo "vVERSION: "$(vVERSION)
	@echo "CUDA_VERSION: "$(CUDA_VERSION)
	@echo "GOLANG_VERSION: "$(GOLANG_VERSION)
	@echo "GIT_COMMIT: "$(GIT_COMMIT)
	@echo "REGISTRY: "$(REGISTRY)
	@echo "IMAGE_NAME: "$(IMAGE_NAME)
	@echo "BUILDIMAGE_TAG: "$(BUILDIMAGE_TAG)
	@echo "BUILDIMAGE: "$(BUILDIMAGE)
	@echo "EXAMPLES: "$(EXAMPLES)
	@echo "EXAMPLE_TARGETS: "$(EXAMPLE_TARGETS)
	@echo "CMDS: "$(CMDS)
	@echo "CMD_TARGETS: "$(CMD_TARGETS)
	@echo "CHECK_TARGETS: "$(CHECK_TARGETS)
	@echo "MAKE_TARGETS: "$(MAKE_TARGETS)
	@echo "TARGETS: "$(TARGETS)
	@echo "DOCKER_TARGETS: "$(DOCKER_TARGETS)
	@echo "CLI_VERSION: "$(CLI_VERSION)
	@echo "CLI_VERSION_PACKAGE: "$(CLI_VERSION_PACKAGE)
	@echo "GOOS: "$(GOOS)
	@echo "COMMAND_BUILD_OPTIONS: "$(COMMAND_BUILD_OPTIONS)

# CMD_TARGETS: cmd-config-manager cmd-nvidia-device-plugin
$(CMD_TARGETS): cmd-%:
	CGO_LDFLAGS_ALLOW='-Wl,--unresolved-symbols=ignore-in-object-files' GOOS=$(GOOS) \
		go build -ldflags "-s -w -X $(CLI_VERSION_PACKAGE).gitCommit=$(GIT_COMMIT) -X $(CLI_VERSION_PACKAGE).version=$(CLI_VERSION)" $(COMMAND_BUILD_OPTIONS) $(MODULE)/cmd/$(*)
# $ make -n --just-print cmd-config-manager
# CGO_LDFLAGS_ALLOW='-Wl,--unresolved-symbols=ignore-in-object-files' GOOS=linux \
# 		go build -ldflags "-s -w -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.14.0"  github.com/NVIDIA/k8s-device-plugin/cmd/config-manager
# $

# $ make -n --just-print cmd-nvidia-device-plugin
# CGO_LDFLAGS_ALLOW='-Wl,--unresolved-symbols=ignore-in-object-files' GOOS=linux \
# 		go build -ldflags "-s -w -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.14.0"  github.com/NVIDIA/k8s-device-plugin/cmd/nvidia-device-plugin
# $

build:
	GOOS=$(GOOS) go build ./...
# $ make -n --just-print build
# GOOS=linux go build ./...
# $

examples: $(EXAMPLE_TARGETS)
# $ make -n --just-print examples
# make: Nothing to be done for `examples'.
# $

# EXAMPLE_TARGETS:
$(EXAMPLE_TARGETS): example-%:
	GOOS=$(GOOS) go build ./examples/$(*)

all: check test build binary
check: $(CHECK_TARGETS)
# CHECK_TARGETS: assert-fmt vet lint ineffassign misspell
# $ make -n --just-print check
# go list -f '{{.Dir}}' github.com/NVIDIA/k8s-device-plugin/... \
# 		| xargs gofmt -s -l > fmt.out
# if [ -s fmt.out ]; then \
# 		echo "\nERROR: The following files are not formatted:\n"; \
# 		cat fmt.out; \
# 		rm fmt.out; \
# 		exit 1; \
# 	else \
# 		rm fmt.out; \
# 	fi
# go vet github.com/NVIDIA/k8s-device-plugin/...
# go list -f '{{.Dir}}' github.com/NVIDIA/k8s-device-plugin/... | xargs golint -set_exit_status
# ineffassign github.com/NVIDIA/k8s-device-plugin/...
# misspell github.com/NVIDIA/k8s-device-plugin/...
# $

# Apply go fmt to the codebase
fmt:
	go list -f '{{.Dir}}' $(MODULE)/... \
		| xargs gofmt -s -l -w
# $ make -n --just-print fmt
# go list -f '{{.Dir}}' github.com/NVIDIA/k8s-device-plugin/... \
# 		| xargs gofmt -s -l -w
# $

assert-fmt:
	go list -f '{{.Dir}}' $(MODULE)/... \
		| xargs gofmt -s -l > fmt.out
	@if [ -s fmt.out ]; then \
		echo "\nERROR: The following files are not formatted:\n"; \
		cat fmt.out; \
		rm fmt.out; \
		exit 1; \
	else \
		rm fmt.out; \
	fi
# $ make -n --just-print assert-fmt
# go list -f '{{.Dir}}' github.com/NVIDIA/k8s-device-plugin/... \
# 		| xargs gofmt -s -l > fmt.out
# if [ -s fmt.out ]; then \
# 		echo "\nERROR: The following files are not formatted:\n"; \
# 		cat fmt.out; \
# 		rm fmt.out; \
# 		exit 1; \
# 	else \
# 		rm fmt.out; \
# 	fi
# $

ineffassign:
	ineffassign $(MODULE)/...
# $ make -n --just-print ineffassign
# ineffassign github.com/NVIDIA/k8s-device-plugin/...
# $

lint:
# We use `go list -f '{{.Dir}}' $(MODULE)/...` to skip the `vendor` folder.
	go list -f '{{.Dir}}' $(MODULE)/... | xargs golint -set_exit_status
# $ make -n --just-print lint
# go list -f '{{.Dir}}' github.com/NVIDIA/k8s-device-plugin/... | xargs golint -set_exit_status
# $

lint-internal:
# We use `go list -f '{{.Dir}}' $(MODULE)/...` to skip the `vendor` folder.
	go list -f '{{.Dir}}' $(MODULE)/internal/... | xargs golint -set_exit_status
# $ make -n --just-print lint-internal
# go list -f '{{.Dir}}' github.com/NVIDIA/k8s-device-plugin/internal/... | xargs golint -set_exit_status
# $

misspell:
	misspell $(MODULE)/...
# $ make -n --just-print misspell
# misspell github.com/NVIDIA/k8s-device-plugin/...
# $

vet:
	go vet $(MODULE)/...
# $ make -n --just-print vet
# go vet github.com/NVIDIA/k8s-device-plugin/...
# $

COVERAGE_FILE := coverage.out
test: build cmds
	go test -v -coverprofile=$(COVERAGE_FILE) $(MODULE)/...
# $ make -n --just-print test
# GOOS=linux go build ./...
# CGO_LDFLAGS_ALLOW='-Wl,--unresolved-symbols=ignore-in-object-files' GOOS=linux \
# 		go build -ldflags "-s -w -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.14.0"  github.com/NVIDIA/k8s-device-plugin/cmd/config-manager
# CGO_LDFLAGS_ALLOW='-Wl,--unresolved-symbols=ignore-in-object-files' GOOS=linux \
# 		go build -ldflags "-s -w -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.14.0"  github.com/NVIDIA/k8s-device-plugin/cmd/nvidia-device-plugin
# go test -v -coverprofile=coverage.out github.com/NVIDIA/k8s-device-plugin/...
# $

coverage: test
	cat $(COVERAGE_FILE) | grep -v "_mock.go" > $(COVERAGE_FILE).no-mocks
	go tool cover -func=$(COVERAGE_FILE).no-mocks
# $ make -n --just-print coverage
# GOOS=linux go build ./...
# CGO_LDFLAGS_ALLOW='-Wl,--unresolved-symbols=ignore-in-object-files' GOOS=linux \
# 		go build -ldflags "-s -w -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.14.0"  github.com/NVIDIA/k8s-device-plugin/cmd/config-manager
# CGO_LDFLAGS_ALLOW='-Wl,--unresolved-symbols=ignore-in-object-files' GOOS=linux \
# 		go build -ldflags "-s -w -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.14.0"  github.com/NVIDIA/k8s-device-plugin/cmd/nvidia-device-plugin
# go test -v -coverprofile=coverage.out github.com/NVIDIA/k8s-device-plugin/...
# cat coverage.out | grep -v "_mock.go" > coverage.out.no-mocks
# go tool cover -func=coverage.out.no-mocks
# $

generate:
	go generate $(MODULE)/...
# $ make -n --just-print generate
# go generate github.com/NVIDIA/k8s-device-plugin/...
# $

# Generate an image for containerized builds
# Note: This image is local only
.PHONY: .build-image .pull-build-image .push-build-image
.build-image: docker/Dockerfile.devel
	if [ x"$(SKIP_IMAGE_BUILD)" = x"" ]; then \
		$(DOCKER) build \
			--progress=plain \
			--build-arg GOLANG_VERSION="$(GOLANG_VERSION)" \
			--tag $(BUILDIMAGE) \
			-f $(^) \
			docker; \
	fi
# $ make -n --just-print .build-image
# if [ x"" = x"" ]; then \
# 		docker build \
# 			--progress=plain \
# 			--build-arg GOLANG_VERSION="1.20.2" \
# 			--tag nvidia/k8s-device-plugin-build:golang1.20.2 \
# 			-f docker/Dockerfile.devel \
# 			docker; \
# 	fi
# $

.pull-build-image:
	$(DOCKER) pull $(BUILDIMAGE)
# $ make -n --just-print .pull-build-image
# docker pull nvidia/k8s-device-plugin-build:golang1.20.2
# $

.push-build-image:
	$(DOCKER) push $(BUILDIMAGE)
# $ make -n --just-print .push-build-image
# docker push nvidia/k8s-device-plugin-build:golang1.20.2
# $

# DOCKER_TARGETS: docker-binaries docker-build docker-check docker-fmt docker-lint-internal docker-test docker-examples docker-cmds docker-coverage docker-generate docker-assert-fmt docker-vet docker-lint docker-ineffassign docker-misspell docker-cmd-config-manager docker-cmd-nvidia-device-plugin
$(DOCKER_TARGETS): docker-%: .build-image
	@echo "Running 'make $(*)' in docker container $(BUILDIMAGE)"
	$(DOCKER) run \
		--rm \
		-e GOCACHE=/tmp/.cache \
		-v $(PWD):$(PWD) \
		-w $(PWD) \
		--user $$(id -u):$$(id -g) \
		$(BUILDIMAGE) \
			make $(*)

# $ make -n --just-print docker-binaries
# if [ x"" = x"" ]; then \
# 		docker build \
# 			--progress=plain \
# 			--build-arg GOLANG_VERSION="1.20.2" \
# 			--tag nvidia/k8s-device-plugin-build:golang1.20.2 \
# 			-f docker/Dockerfile.devel \
# 			docker; \
# 	fi
# echo "Running 'make binaries' in docker container nvidia/k8s-device-plugin-build:golang1.20.2"
# docker run \
# 		--rm \
# 		-e GOCACHE=/tmp/.cache \
# 		-v /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia:/Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia \
# 		-w /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia \
# 		--user $(id -u):$(id -g) \
# 		nvidia/k8s-device-plugin-build:golang1.20.2 \
# 			make binaries
# $

# $ make -n --just-print docker-build
# if [ x"" = x"" ]; then \
# 		docker build \
# 			--progress=plain \
# 			--build-arg GOLANG_VERSION="1.20.2" \
# 			--tag nvidia/k8s-device-plugin-build:golang1.20.2 \
# 			-f docker/Dockerfile.devel \
# 			docker; \
# 	fi
# echo "Running 'make build' in docker container nvidia/k8s-device-plugin-build:golang1.20.2"
# docker run \
# 		--rm \
# 		-e GOCACHE=/tmp/.cache \
# 		-v /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia:/Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia \
# 		-w /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia \
# 		--user $(id -u):$(id -g) \
# 		nvidia/k8s-device-plugin-build:golang1.20.2 \
# 			make build
# $

# Start an interactive shell using the development image.
PHONY: .shell
.shell:
	$(DOCKER) run \
		--rm \
		-ti \
		-e GOCACHE=/tmp/.cache \
		-v $(PWD):$(PWD) \
		-w $(PWD) \
		--user $$(id -u):$$(id -g) \
		$(BUILDIMAGE)
# $ make -n --just-print .shell
# docker run \
# 		--rm \
# 		-ti \
# 		-e GOCACHE=/tmp/.cache \
# 		-v /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia:/Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia \
# 		-w /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia \
# 		--user $(id -u):$(id -g) \
# 		nvidia/k8s-device-plugin-build:golang1.20.2
# $
