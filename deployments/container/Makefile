# Copyright (c) 2021-2022, NVIDIA CORPORATION.  All rights reserved.
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

BUILD_MULTI_ARCH_IMAGES ?= no
DOCKER ?= docker
BUILDX  =
ifeq ($(BUILD_MULTI_ARCH_IMAGES),true)
BUILDX = buildx
endif
MKDIR    ?= mkdir

##### Global variables #####
include $(CURDIR)/versions.mk

ifeq ($(IMAGE_NAME),)
REGISTRY ?= nvcr.io/nvidia
IMAGE_NAME := $(REGISTRY)/k8s-device-plugin
endif

IMAGE_VERSION := $(VERSION)

IMAGE_TAG ?= $(IMAGE_VERSION)-$(DIST)
IMAGE = $(IMAGE_NAME):$(IMAGE_TAG)

OUT_IMAGE_NAME ?= $(IMAGE_NAME)
OUT_IMAGE_VERSION ?= $(IMAGE_VERSION)
OUT_IMAGE_TAG = $(OUT_IMAGE_VERSION)-$(DIST)
OUT_IMAGE = $(OUT_IMAGE_NAME):$(OUT_IMAGE_TAG)

##### Public rules #####
DEFAULT_PUSH_TARGET := ubuntu20.04
DISTRIBUTIONS = $(DEFAULT_PUSH_TARGET) ubi8

BUILD_TARGETS := $(patsubst %,build-%,$(DISTRIBUTIONS))
PUSH_TARGETS := $(patsubst %,push-%,$(DISTRIBUTIONS))
TEST_TARGETS := $(patsubst %,test-%, $(DISTRIBUTIONS))

.PHONY: $(DISTRIBUTIONS) $(PUSH_TARGETS) $(BUILD_TARGETS) $(TEST_TARGETS)

ifneq ($(BUILD_MULTI_ARCH_IMAGES),true)
include $(CURDIR)/deployments/container/native-only.mk
else
include $(CURDIR)/deployments/container/multi-arch.mk
endif

# For the default push target we also push a short tag equal to the version.
# We skip this for the development release
DEVEL_RELEASE_IMAGE_VERSION ?= devel
PUSH_MULTIPLE_TAGS ?= true
ifeq ($(strip $(OUT_IMAGE_VERSION)),$(DEVEL_RELEASE_IMAGE_VERSION))
PUSH_MULTIPLE_TAGS = false
endif
ifeq ($(PUSH_MULTIPLE_TAGS),true)
push-$(DEFAULT_PUSH_TARGET): push-short
endif

push-%: DIST = $(*)
push-short: DIST = $(DEFAULT_PUSH_TARGET)

build-%: DIST = $(*)
build-%: DOCKERFILE = $(CURDIR)/deployments/container/Dockerfile.$(DOCKERFILE_SUFFIX)

# Use a generic build target to build the relevant images
$(BUILD_TARGETS): build-%:
	DOCKER_BUILDKIT=1 \
		$(DOCKER) $(BUILDX) build --pull \
		$(DOCKER_BUILD_OPTIONS) \
		$(DOCKER_BUILD_PLATFORM_OPTIONS) \
		--tag $(IMAGE) \
		--build-arg BASE_DIST="$(DIST)" \
		--build-arg CUDA_VERSION="$(CUDA_VERSION)" \
		--build-arg GOLANG_VERSION="$(GOLANG_VERSION)" \
		--build-arg VERSION="$(VERSION)" \
		--build-arg GIT_COMMIT="$(GIT_COMMIT)" \
		--build-arg CVE_UPDATES="$(CVE_UPDATES)" \
		-f $(DOCKERFILE) \
		$(CURDIR)

build-ubuntu%: DOCKERFILE_SUFFIX := ubuntu

build-ubi8: DOCKERFILE_SUFFIX := ubi8


print:
	@echo "BUILD_MULTI_ARCH_IMAGES: "$(BUILD_MULTI_ARCH_IMAGES)
	@echo "DOCKER: "$(DOCKER)
	@echo "BUILDX: "$(BUILDX)
	@echo "MKDIR: "$(MKDIR)
	@echo "MODULE: "$(MODULE)
	@echo "VERSION: "$(VERSION)
	@echo "vVERSION: "$(vVERSION)
	@echo "CUDA_VERSION: "$(CUDA_VERSION)
	@echo "GOLANG_VERSION: "$(GOLANG_VERSION)
	@echo "GIT_COMMIT: "$(GIT_COMMIT)
	@echo "REGISTRY: "$(REGISTRY)
	@echo "IMAGE_NAME: "$(IMAGE_NAME)
	@echo "IMAGE_VERSION: "$(IMAGE_VERSION)
	@echo "IMAGE_TAG: "$(IMAGE_TAG)
	@echo "IMAGE: "$(IMAGE)
	@echo "OUT_IMAGE_NAME: "$(OUT_IMAGE_NAME)
	@echo "OUT_IMAGE_VERSION: "$(OUT_IMAGE_VERSION)
	@echo "OUT_IMAGE_TAG: "$(OUT_IMAGE_TAG)
	@echo "OUT_IMAGE: "$(OUT_IMAGE)
	@echo "DEFAULT_PUSH_TARGET: "$(DEFAULT_PUSH_TARGET)
	@echo "DISTRIBUTIONS: "$(DISTRIBUTIONS)
	@echo "BUILD_TARGETS: "$(BUILD_TARGETS)
	@echo "PUSH_TARGETS: "$(PUSH_TARGETS)
	@echo "TEST_TARGETS: "$(TEST_TARGETS)

	@echo "DEVEL_RELEASE_IMAGE_VERSION: "$(DEVEL_RELEASE_IMAGE_VERSION)
	@echo "PUSH_MULTIPLE_TAGS: "$(PUSH_MULTIPLE_TAGS)

# $ make -f deployments/container/Makefile BUILD_MULTI_ARCH_IMAGES=no print
# BUILD_MULTI_ARCH_IMAGES: no
# DOCKER: docker
# BUILDX:
# MKDIR: mkdir
# MODULE: github.com/NVIDIA/k8s-device-plugin
# VERSION: v0.14.0
# vVERSION: v0.14.0
# CUDA_VERSION: 12.1.0
# GOLANG_VERSION: 1.20.2
# GIT_COMMIT: e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty
# REGISTRY: nvcr.io/nvidia
# IMAGE_NAME: nvcr.io/nvidia/k8s-device-plugin
# IMAGE_VERSION: v0.14.0
# IMAGE_TAG: v0.14.0-
# IMAGE: nvcr.io/nvidia/k8s-device-plugin:v0.14.0-
# OUT_IMAGE_NAME: nvcr.io/nvidia/k8s-device-plugin
# OUT_IMAGE_VERSION: v0.14.0
# OUT_IMAGE_TAG: v0.14.0-
# OUT_IMAGE: nvcr.io/nvidia/k8s-device-plugin:v0.14.0-
# DEFAULT_PUSH_TARGET: ubuntu20.04
# DISTRIBUTIONS: ubuntu20.04 ubi8
# BUILD_TARGETS: build-ubuntu20.04 build-ubi8
# PUSH_TARGETS: push-ubuntu20.04 push-ubi8
# TEST_TARGETS: test-ubuntu20.04 test-ubi8
# DEVEL_RELEASE_IMAGE_VERSION: devel
# PUSH_MULTIPLE_TAGS: true

# $ make -f deployments/container/Makefile BUILD_MULTI_ARCH_IMAGES=no build-ubuntu20.04 -n
# echo "DIST: "ubuntu20.04
# echo "DOCKERFILE: "/Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia/deployments/container/Dockerfile.ubuntu
# echo "DOCKER_BUILD_OPTIONS: "
# DOCKER_BUILDKIT=1 \
# 		docker  build --pull \
# 		 \
# 		--platform=linux/amd64 \
# 		--tag nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubuntu20.04 \
# 		--build-arg BASE_DIST="ubuntu20.04" \
# 		--build-arg CUDA_VERSION="12.1.0" \
# 		--build-arg GOLANG_VERSION="1.20.2" \
# 		--build-arg VERSION="v0.14.0" \
# 		--build-arg GIT_COMMIT="e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty" \
# 		--build-arg CVE_UPDATES="" \
# 		-f /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia/deployments/container/Dockerfile.ubuntu \
# 		/Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia

# $ make -f deployments/container/Makefile BUILD_MULTI_ARCH_IMAGES=no push-ubuntu20.04 -n
# docker tag "nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubuntu20.04" "nvcr.io/nvidia/k8s-device-plugin:v0.14.0"
# docker push "nvcr.io/nvidia/k8s-device-plugin:v0.14.0"
# docker tag "nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubuntu20.04" "nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubuntu20.04"
# docker push "nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubuntu20.04"
# $

# $ make -f deployments/container/Makefile BUILD_MULTI_ARCH_IMAGES=no build-ubi8 -n
# echo "DIST: "ubi8
# echo "DOCKERFILE: "/Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia/deployments/container/Dockerfile.ubi8
# echo "DOCKER_BUILD_OPTIONS: "
# DOCKER_BUILDKIT=1 \
# 		docker  build --pull \
# 		 \
# 		--platform=linux/amd64 \
# 		--tag nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubi8 \
# 		--build-arg BASE_DIST="ubi8" \
# 		--build-arg CUDA_VERSION="12.1.0" \
# 		--build-arg GOLANG_VERSION="1.20.2" \
# 		--build-arg VERSION="v0.14.0" \
# 		--build-arg GIT_COMMIT="e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty" \
# 		--build-arg CVE_UPDATES="" \
# 		-f /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia/deployments/container/Dockerfile.ubi8 \
# 		/Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia

# $ make -f deployments/container/Makefile BUILD_MULTI_ARCH_IMAGES=no push-ubi8 -n
# docker tag "nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubi8" "nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubi8"
# docker push "nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubi8"
# $


# $ make -f deployments/container/Makefile BUILD_MULTI_ARCH_IMAGES=true print
# BUILD_MULTI_ARCH_IMAGES: true
# DOCKER: docker
# BUILDX: buildx
# MKDIR: mkdir
# MODULE: github.com/NVIDIA/k8s-device-plugin
# VERSION: v0.14.0
# vVERSION: v0.14.0
# CUDA_VERSION: 12.1.0
# GOLANG_VERSION: 1.20.2
# GIT_COMMIT: e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty
# REGISTRY: nvcr.io/nvidia
# IMAGE_NAME: nvcr.io/nvidia/k8s-device-plugin
# IMAGE_VERSION: v0.14.0
# IMAGE_TAG: v0.14.0-
# IMAGE: nvcr.io/nvidia/k8s-device-plugin:v0.14.0-
# OUT_IMAGE_NAME: nvcr.io/nvidia/k8s-device-plugin
# OUT_IMAGE_VERSION: v0.14.0
# OUT_IMAGE_TAG: v0.14.0-
# OUT_IMAGE: nvcr.io/nvidia/k8s-device-plugin:v0.14.0-
# DEFAULT_PUSH_TARGET: ubuntu20.04
# DISTRIBUTIONS: ubuntu20.04 ubi8
# BUILD_TARGETS: build-ubuntu20.04 build-ubi8
# PUSH_TARGETS: push-ubuntu20.04 push-ubi8
# TEST_TARGETS: test-ubuntu20.04 test-ubi8
# DEVEL_RELEASE_IMAGE_VERSION: devel
# PUSH_MULTIPLE_TAGS: true

# $ make -f deployments/container/Makefile BUILD_MULTI_ARCH_IMAGES=true build-ubuntu20.04 -n
# echo "DIST: "ubuntu20.04
# echo "DOCKERFILE: "/Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia/deployments/container/Dockerfile.ubuntu
# echo "DOCKER_BUILD_OPTIONS: "--output=type=image,push=false
# DOCKER_BUILDKIT=1 \
# 		docker buildx build --pull \
# 		--output=type=image,push=false \
# 		--platform=linux/amd64,linux/arm64 \
# 		--tag nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubuntu20.04 \
# 		--build-arg BASE_DIST="ubuntu20.04" \
# 		--build-arg CUDA_VERSION="12.1.0" \
# 		--build-arg GOLANG_VERSION="1.20.2" \
# 		--build-arg VERSION="v0.14.0" \
# 		--build-arg GIT_COMMIT="e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty" \
# 		--build-arg CVE_UPDATES="" \
# 		-f /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia/deployments/container/Dockerfile.ubuntu \
# 		/Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia

# $ make -f deployments/container/Makefile BUILD_MULTI_ARCH_IMAGES=true push-ubuntu20.04 -n
# regctl \
# 	        image copy \
# 	        nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubuntu20.04 nvcr.io/nvidia/k8s-device-plugin:v0.14.0
# regctl \
# 	        image copy \
# 	        nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubuntu20.04 nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubuntu20.04
# $

# $ make -f deployments/container/Makefile BUILD_MULTI_ARCH_IMAGES=true build-ubi8 -n
# echo "DIST: "ubi8
# echo "DOCKERFILE: "/Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia/deployments/container/Dockerfile.ubi8
# echo "DOCKER_BUILD_OPTIONS: "--output=type=image,push=false
# DOCKER_BUILDKIT=1 \
# 		docker buildx build --pull \
# 		--output=type=image,push=false \
# 		--platform=linux/amd64,linux/arm64 \
# 		--tag nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubi8 \
# 		--build-arg BASE_DIST="ubi8" \
# 		--build-arg CUDA_VERSION="12.1.0" \
# 		--build-arg GOLANG_VERSION="1.20.2" \
# 		--build-arg VERSION="v0.14.0" \
# 		--build-arg GIT_COMMIT="e6c111aff19eab995e8d0f4345169e8c310d2f9c-dirty" \
# 		--build-arg CVE_UPDATES="" \
# 		-f /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia/deployments/container/Dockerfile.ubi8 \
# 		/Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin-nvidia

# $ make -f deployments/container/Makefile BUILD_MULTI_ARCH_IMAGES=true push-ubi8 -n
# regctl \
# 	        image copy \
# 	        nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubi8 nvcr.io/nvidia/k8s-device-plugin:v0.14.0-ubi8

# $
