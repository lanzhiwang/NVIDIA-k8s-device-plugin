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

# ==========================================
# 1. 基础变量定义
# ==========================================

# 使用 ?= 进行条件赋值: 如果环境变量中已经定义了 DOCKER, 则使用环境变量的值; 否则默认使用 "docker".
# 这极大地方便了 CI/CD 环境替换底层容器引擎(如替换为 podman).
DOCKER   ?= docker
# DOCKER: docker

# 同上, 设置创建目录的默认命令.
MKDIR    ?= mkdir
# MKDIR: mkdir

# 定义构建产物的输出目录. $(CURDIR) 是 Make 的内置变量, 代表当前 Makefile 所在的绝对路径.
DIST_DIR ?= $(CURDIR)/dist
# CURDIR: /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin
# DIST_DIR: /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin/dist

# 引入外部的 Makefile 片段. 通常 versions.mk 中会包含如 VERSION 等版本信息的变量定义.
include $(CURDIR)/versions.mk

# ==========================================
# 2. 镜像仓库与名称配置
# ==========================================

# 检查变量 IMAGE_NAME 是否为空.
ifeq ($(IMAGE_NAME),)
# 如果为空, 设置默认的镜像仓库名称为 nvidia.
REGISTRY ?= nvidia
# 并拼接出完整的镜像名称.
IMAGE_NAME = $(REGISTRY)/k8s-device-plugin
endif
# IMAGE_NAME: nvcr.io/nvidia/k8s-device-plugin

# ==========================================
# 3. 动态获取目标列表 (重点技巧)
# ==========================================

# 这是一套非常经典的组合拳, 用于动态获取 ./examples/ 目录下的所有子目录名.
# 1. wildcard ./examples/*/: 获取所有子目录的路径(带有斜杠结尾).
# 2. dir: 提取目录部分(这里主要为了确保格式统一).
# 3. sort: 排序并去重.
# 4. patsubst ./examples/%/,%,...: 模式替换, 把带有路径和斜杠的字符串(如 ./examples/foo/)替换为纯名字(foo).
EXAMPLES := $(patsubst ./examples/%/,%,$(sort $(dir $(wildcard ./examples/*/))))
# EXAMPLES:

# 为每一个 example 生成一个 Make 目标名, 例如: 如果 EXAMPLES 是 a b, 那么 EXAMPLE_TARGETS 就是 example-a example-b.
EXAMPLE_TARGETS := $(patsubst %,example-%, $(EXAMPLES))
# EXAMPLE_TARGETS:

# 与上面同理, 动态获取 ./cmd/ 目录下的所有子命令目录名.
CMDS := $(patsubst ./cmd/%/,%,$(sort $(dir $(wildcard ./cmd/*/))))
# CMDS: config-manager gpu-feature-discovery mps-control-daemon nvidia-device-plugin

# 生成形如 cmd-foo 的目标列表.
CMD_TARGETS := $(patsubst %,cmd-%, $(CMDS))
# CMD_TARGETS: cmd-config-manager cmd-gpu-feature-discovery cmd-mps-control-daemon cmd-nvidia-device-plugin

# 定义代码检查的 target 名称.
CHECK_TARGETS := lint
# CHECK_TARGETS: lint

# 定义项目中所有的常规 Make target 集合.
MAKE_TARGETS := binaries build check fmt lint-internal test examples cmds coverage generate vendor check-modules $(CHECK_TARGETS)
# MAKE_TARGETS: binaries build check fmt lint-internal test examples cmds coverage generate vendor check-modules lint

# 将常规 target、示例 target 和命令行 target 合并为一个总的目标集合.
TARGETS := $(MAKE_TARGETS) $(EXAMPLE_TARGETS) $(CMD_TARGETS)
# TARGETS: binaries build check fmt lint-internal test examples cmds coverage generate vendor check-modules lint cmd-config-manager cmd-gpu-feature-discovery cmd-mps-control-daemon cmd-nvidia-device-plugin

# 为所有的 target 生成对应的 docker 版本, 形如 docker-build, docker-test 等.
# 用于在 Docker 容器内部执行对应的 Make 命令.
DOCKER_TARGETS := $(patsubst %,docker-%, $(TARGETS))
# DOCKER_TARGETS: docker-binaries docker-build docker-check docker-fmt docker-lint-internal docker-test docker-examples docker-cmds docker-coverage docker-generate docker-vendor docker-check-modules docker-lint docker-cmd-config-manager docker-cmd-gpu-feature-discovery docker-cmd-mps-control-daemon docker-cmd-nvidia-device-plugin

# 将这些目标声明为伪目标(Phony Targets).
# 这告诉 Make 这些词是命令名字, 而不是实际的文件名, 防止因为目录下偶然存在同名文件而导致规则不执行.
.PHONY: $(TARGETS) $(DOCKER_TARGETS)

# ==========================================
# 4. Go 编译版本号注入配置
# ==========================================

# 判断版本号是否为空, 决定使用 versions.mk 中定义的哪个变量组合.
ifeq ($(VERSION),)
# 如果没有明确传 VERSION, 则使用 LIB_VERSION 和 LIB_TAG 拼接. $(if ...) 是 Make 的条件函数.
CLI_VERSION = $(LIB_VERSION)$(if $(LIB_TAG),-$(LIB_TAG))
else
# 如果外界传了 VERSION, 则直接使用.
CLI_VERSION = $(VERSION)
endif
# CLI_VERSION: v0.19.0

# 定义 Go 代码中需要被动态注入版本号的包路径.
CLI_VERSION_PACKAGE = github.com/NVIDIA/k8s-device-plugin/internal/info
# CLI_VERSION_PACKAGE: github.com/NVIDIA/k8s-device-plugin/internal/info

# 别名目标: 执行 make binaries 实际上就是执行 make cmds.
binaries: cmds

# 如果定义了 PREFIX(通常指安装目录的绝对路径).
ifneq ($(PREFIX),)
# 这里利用了 Target-specific Variable Values (目标特定变量).
# 意思是: 针对所有匹配 cmd-% 的目标, 设置 COMMAND_BUILD_OPTIONS 变量, 指定 Go 构建的输出路径 (-o).
# $(*) 代表匹配模式 % 时的实际内容(stem).
cmd-%: COMMAND_BUILD_OPTIONS = -o $(PREFIX)/$(*)
endif

# ==========================================
# 5. CGO / 链接器参数配置
# ==========================================

# 通过 shell 执行 uname 命令判断操作系统.
ifneq ($(shell uname),Darwin)
# 如果不是 macOS (Darwin), 即 Linux 环境.
# 设置外部链接器参数, 允许导出动态符号, 并忽略未解析的符号(这在构建某些以插件形式运行的 CGO 程序时很常见).
EXTLDFLAGS = -Wl,--export-dynamic -Wl,--unresolved-symbols=ignore-in-object-files
else
# 如果是 macOS.
# 使用 macOS 链接器特有的参数来实现动态查找未定义符号.
EXTLDFLAGS = -Wl,-undefined,dynamic_lookup
endif
# EXTLDFLAGS: -Wl,-undefined,dynamic_lookup

# 定义 Go 编译器的完整标志位:
# -s -w: 剥离符号表和 DWARF 调试信息, 能显著减小编译出的二进制文件体积.
# -extldflags: 传入上面定义的 C 链接器参数.
# -X: 链接期动态注入变量的值(将 Git commit ID 和 版本号注入到代码中).
BUILDFLAGS = -ldflags "-s -w '-extldflags=$(EXTLDFLAGS)' -X $(CLI_VERSION_PACKAGE).gitCommit=$(GIT_COMMIT) -X $(CLI_VERSION_PACKAGE).version=$(CLI_VERSION)"
# BUILDFLAGS: -ldflags -s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0

# ==========================================
# 6. Go 构建规则
# ==========================================

# 构建整个项目.
build:
	go build $(BUILDFLAGS) ./...
# $ make -n --just-print build
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" ./...
# $ PREFIX=lanzhiwang make -n --just-print build
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" ./...
# $

# 别名目标: 构建所有 cmd 子命令. 依赖于动态生成的 CMD_TARGETS.
cmds: $(CMD_TARGETS)
# $ make -n --just-print cmds
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/config-manager
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/gpu-feature-discovery
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/mps-control-daemon
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/nvidia-device-plugin
# $ PREFIX=lanzhiwang make -n --just-print cmds
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/config-manager github.com/NVIDIA/k8s-device-plugin/cmd/config-manager
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/gpu-feature-discovery github.com/NVIDIA/k8s-device-plugin/cmd/gpu-feature-discovery
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/mps-control-daemon github.com/NVIDIA/k8s-device-plugin/cmd/mps-control-daemon
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/nvidia-device-plugin github.com/NVIDIA/k8s-device-plugin/cmd/nvidia-device-plugin
# $

# 静态模式规则 (Static Pattern Rules). 语法: targets ...: target-pattern: prereq-patterns
# 它告诉 Make 如何构建 $(CMD_TARGETS) 列表里的元素.
$(CMD_TARGETS): cmd-%:
# 实际的构建命令. $(MODULE) 未在此文件中定义, 推测在外部环境变量或 versions.mk 中.
# $(*) 提取 target 中的名字(比如从 cmd-server 提取 server), 用于指定源码目录.
	go build $(BUILDFLAGS) $(COMMAND_BUILD_OPTIONS) $(MODULE)/cmd/$(*)

# 规则同上, 构建所有的 example 二进制文件.
examples: $(EXAMPLE_TARGETS)
$(EXAMPLE_TARGETS): example-%:
	go build $(BUILDFLAGS) $(COMMAND_BUILD_OPTIONS) ./examples/$(*)

# ==========================================
# 7. 测试相关规则
# ==========================================

# 声明测试目标为伪目标.
# We also add top-level targets for testing make targets:
.PHONY: $(TEST_TARGETS)
# 动态获取 ./tests/ 下的所有子目录名.
TESTS_FOLDERS := $(patsubst ./tests/%/,%,$(sort $(dir $(wildcard ./tests/*/))))
# 生成形如 test-foo 的测试目标.
TEST_TARGETS := $(patsubst %,test-%,$(TESTS_FOLDERS))
# 静态模式规则: 如何执行子模块的测试.
$(TEST_TARGETS): test-%:
# 进入 tests/对应的子目录, 执行该目录下的 Makefile 中的 test 目标. (Sub-make 调用)
	make -f tests/$(*)/Makefile test

# 聚合目标: 执行 all 会依次进行 检查、测试、构建、以及编译可执行文件.
all: check test build binaries
# $ make -n --just-print all
# golangci-lint run ./...
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" ./...
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/config-manager
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/gpu-feature-discovery
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/mps-control-daemon
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/nvidia-device-plugin
# go test -coverprofile=coverage.out github.com/NVIDIA/k8s-device-plugin/cmd/... github.com/NVIDIA/k8s-device-plugin/internal/... github.com/NVIDIA/k8s-device-plugin/api/...
# $ PREFIX=lanzhiwang make -n --just-print all
# golangci-lint run ./...
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" ./...
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/config-manager github.com/NVIDIA/k8s-device-plugin/cmd/config-manager
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/gpu-feature-discovery github.com/NVIDIA/k8s-device-plugin/cmd/gpu-feature-discovery
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/mps-control-daemon github.com/NVIDIA/k8s-device-plugin/cmd/mps-control-daemon
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/nvidia-device-plugin github.com/NVIDIA/k8s-device-plugin/cmd/nvidia-device-plugin
# go test -coverprofile=coverage.out github.com/NVIDIA/k8s-device-plugin/cmd/... github.com/NVIDIA/k8s-device-plugin/internal/... github.com/NVIDIA/k8s-device-plugin/api/...
# $

# check 目标依赖于 lint 等检查工具.
check: $(CHECK_TARGETS)
# $ make -n --just-print check
# golangci-lint run ./...
# $

# ==========================================
# 8. 代码格式化与规范化工具
# ==========================================

# 使用 gofmt 格式化代码库.
# Apply go fmt to the codebase
fmt:
# 使用 go list 找出所有包所在目录, 通过管道传给 xargs 批量执行 gofmt.
	go list -f '{{.Dir}}' $(MODULE)/... \
		| xargs gofmt -s -l -w
# $ make -n --just-print fmt
# go list -f '{{.Dir}}' github.com/NVIDIA/k8s-device-plugin/... \
# 		| xargs gofmt -s -l -w
# $ PREFIX=lanzhiwang make -n --just-print fmt
# go list -f '{{.Dir}}' github.com/NVIDIA/k8s-device-plugin/... \
# 		| xargs gofmt -s -l -w
# $

# 使用 goimports 处理 import 排序和缺失.
goimports:
# -local $(MODULE) 让项目自身的包和第三方包隔离开来.
	go list -f {{.Dir}} $(MODULE)/... \
		| xargs goimports -local $(MODULE) -w
# $ make -n --just-print goimports
# go list -f {{.Dir}} github.com/NVIDIA/k8s-device-plugin/... \
# 		| xargs goimports -local github.com/NVIDIA/k8s-device-plugin -w
# $ PREFIX=lanzhiwang make -n --just-print goimports
# go list -f {{.Dir}} github.com/NVIDIA/k8s-device-plugin/... \
# 		| xargs goimports -local github.com/NVIDIA/k8s-device-plugin -w
# $

# 运行 golangci-lint 进行静态代码分析.
lint:
	golangci-lint run ./...

# ==========================================
# 9. Go Modules 依赖管理支持 (支持多模块架构)
# ==========================================

# 整理项目的依赖.
mod-tidy:
# $$(...) 是在 Makefile 中转义 $ 符号的方式, 以便传递给底层的 shell 执行.
# 找出项目内所有的 go.mod 文件(支持嵌套的多模块).
	@for mod in $$(find . -name go.mod); do \
	    echo "Tidying $$mod..."; ( \
	        cd $$(dirname $$mod) && go mod tidy \
            ) || exit 1; \
	done

# 验证依赖的哈希值是否被篡改.
mod-verify:
	@for mod in $$(find . -name go.mod); do \
	    echo "Verifying $$mod..."; ( \
	        cd $$(dirname $$mod) && go mod verify | sed 's/^/  /g' \
	    ) || exit 1; \
	done

# 将依赖打包到 vendor 目录下, 排除 deployments 目录下的脚本/工具依赖.
mod-vendor: mod-tidy
	@for mod in $$(find . -name go.mod -not -path "./deployments/*"); do \
	    echo "Vendoring $$mod..."; ( \
	        cd $$(dirname $$mod) && go mod vendor \
	    ) || exit 1; \
	done

# 别名目标.
vendor: mod-vendor

# 检查当前 git 仓库的模块依赖是否干净(是否有未提交的依赖变更).
# 这里的 `|` 叫 Order-only Prerequisites.
# 意思是: 执行 check-modules 前, 必须先执行 mod-tidy, mod-verify, mod-vendor.
# 但这三个目标的文件时间戳更新, 不会导致 check-modules 被迫重新执行.
check-modules: | mod-tidy mod-verify mod-vendor
# 检查 go.mod, go.sum 或 vendor 目录是否有变更, 如果有, 返回非 0 状态码让 Make 失败.
	git diff --quiet HEAD -- $$(find . -name go.mod -o -name go.sum -o -name vendor)
# $ make -n --just-print check-modules
# for mod in $(find . -name go.mod); do \
# 	    echo "Tidying $mod..."; ( \
# 	        cd $(dirname $mod) && go mod tidy \
#             ) || exit 1; \
# 	done
# for mod in $(find . -name go.mod); do \
# 	    echo "Verifying $mod..."; ( \
# 	        cd $(dirname $mod) && go mod verify | sed 's/^/  /g' \
# 	    ) || exit 1; \
# 	done
# for mod in $(find . -name go.mod -not -path "./deployments/*"); do \
# 	    echo "Vendoring $mod..."; ( \
# 	        cd $(dirname $mod) && go mod vendor \
# 	    ) || exit 1; \
# 	done
# git diff --quiet HEAD -- $(find . -name go.mod -o -name go.sum -o -name vendor)
# $

# ==========================================
# 10. 测试覆盖率与代码生成
# ==========================================

# 覆盖率结果输出文件名.
COVERAGE_FILE := coverage.out

# 执行测试, 依赖 build 和 cmds 先构建成功.
test: build cmds
# 运行 go test 并开启 coverprofile 输出测试覆盖率报告.
	go test -coverprofile=$(COVERAGE_FILE) $(MODULE)/cmd/... $(MODULE)/internal/... $(MODULE)/api/...
# $ make -n --just-print test
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" ./...
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/config-manager
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/gpu-feature-discovery
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/mps-control-daemon
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/nvidia-device-plugin
# go test -coverprofile=coverage.out github.com/NVIDIA/k8s-device-plugin/cmd/... github.com/NVIDIA/k8s-device-plugin/internal/... github.com/NVIDIA/k8s-device-plugin/api/...
# $ PREFIX=lanzhiwang make -n --just-print test
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" ./...
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/config-manager github.com/NVIDIA/k8s-device-plugin/cmd/config-manager
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/gpu-feature-discovery github.com/NVIDIA/k8s-device-plugin/cmd/gpu-feature-discovery
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/mps-control-daemon github.com/NVIDIA/k8s-device-plugin/cmd/mps-control-daemon
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/nvidia-device-plugin github.com/NVIDIA/k8s-device-plugin/cmd/nvidia-device-plugin
# go test -coverprofile=coverage.out github.com/NVIDIA/k8s-device-plugin/cmd/... github.com/NVIDIA/k8s-device-plugin/internal/... github.com/NVIDIA/k8s-device-plugin/api/...
# $

# 查看测试覆盖率.
coverage: test
# 剔除自动生成的 mock 文件对覆盖率的干扰.
	cat $(COVERAGE_FILE) | grep -v "_mock.go" > $(COVERAGE_FILE).no-mocks
# 在终端中以函数级别输出代码覆盖率百分比.
	go tool cover -func=$(COVERAGE_FILE).no-mocks
# $ make -n --just-print coverage
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" ./...
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/config-manager
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/gpu-feature-discovery
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/mps-control-daemon
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0"  github.com/NVIDIA/k8s-device-plugin/cmd/nvidia-device-plugin
# go test -coverprofile=coverage.out github.com/NVIDIA/k8s-device-plugin/cmd/... github.com/NVIDIA/k8s-device-plugin/internal/... github.com/NVIDIA/k8s-device-plugin/api/...
# cat coverage.out | grep -v "_mock.go" > coverage.out.no-mocks
# go tool cover -func=coverage.out.no-mocks
# $ PREFIX=lanzhiwang make -n --just-print coverage
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" ./...
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/config-manager github.com/NVIDIA/k8s-device-plugin/cmd/config-manager
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/gpu-feature-discovery github.com/NVIDIA/k8s-device-plugin/cmd/gpu-feature-discovery
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/mps-control-daemon github.com/NVIDIA/k8s-device-plugin/cmd/mps-control-daemon
# go build -ldflags "-s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0" -o lanzhiwang/nvidia-device-plugin github.com/NVIDIA/k8s-device-plugin/cmd/nvidia-device-plugin
# go test -coverprofile=coverage.out github.com/NVIDIA/k8s-device-plugin/cmd/... github.com/NVIDIA/k8s-device-plugin/internal/... github.com/NVIDIA/k8s-device-plugin/api/...
# cat coverage.out | grep -v "_mock.go" > coverage.out.no-mocks
# go tool cover -func=coverage.out.no-mocks
# $

# 触发代码生成逻辑(如 mockgen, stringer 等 go:generate 指令).
generate:
	go generate $(MODULE)/...

# ==========================================
# 11. 容器化构建环境 (Docker 集成)
# ==========================================

# 声明用于构建基础镜像的目标为伪目标.
# 这是一个仅供本地构建使用的镜像.
# Generate an image for containerized builds
# Note: This image is local only
.PHONY: .build-image
.build-image:
# 调用 deployments 目录下的 Makefile 生成构建所需的 Docker 镜像.
	make -f deployments/devel/Makefile .build-image
# $ make -n --just-print .build-image
# make -f deployments/devel/Makefile .build-image
# $ PREFIX=lanzhiwang make -n --just-print .build-image
# make -f deployments/devel/Makefile .build-image
# $

# 如果开启了 BUILD_DEVEL_IMAGE=yes, 则规定在执行所有 docker-xxx 命令和 .shell 之前,
# 必须先执行 .build-image 确保构建镜像已准备好.
ifeq ($(BUILD_DEVEL_IMAGE),yes)
$(DOCKER_TARGETS): .build-image
.shell: .build-image
endif

# 核心容器化构建规则: 拦截所有 docker-xxx 目标.
$(DOCKER_TARGETS): docker-%:
	@echo "Running 'make $(*)' in container image $(BUILDIMAGE)"
# 启动 Docker 容器:
# --rm: 退出后自动删除容器.
# -e: 注入环境变量, 将 Go 的缓存路径指向临时目录, 加速后续构建.
# -v $(PWD):/work: 将宿主机的当前工作目录挂载到容器内的 /work 目录.
# -w /work: 设置容器内的工作目录为 /work.
# --user $$(id -u):$$(id -g): 以宿主机的当前用户 UID/GID 运行容器, 确保容器内生成的文件在宿主机上不会出现没有 root 权限无法修改的问题！
# $(BUILDIMAGE): 运行的镜像名(未在当前文件定义, 推测在外部环境中).
# make $(*): 在容器内执行对应的实际 make 目标(如 make build).
	$(DOCKER) run \
		--rm \
		-e GOCACHE=/tmp/.cache/go \
		-e GOMODCACHE=/tmp/.cache/gomod \
		-v $(PWD):/work \
		-w /work \
		--user $$(id -u):$$(id -g) \
		$(BUILDIMAGE) \
			make $(*)

# 提供一个便捷的调试后门: 启动一个包含所有构建工具的开发环境 Shell.
# Start an interactive shell using the development image.
.PHONY: .shell
.shell:
# -ti: 分配一个伪终端并保持标准输入打开(交互模式).
# 挂载和权限设置同上, 使得开发者可以在容器里无缝手动敲命令调试.
	$(DOCKER) run \
		--rm \
		-ti \
		-e GOCACHE=/tmp/.cache/go \
		-e GOMODCACHE=/tmp/.cache/gomod \
		-v $(PWD):/work \
		-w /work \
		--user $$(id -u):$$(id -g) \
		$(BUILDIMAGE)

# 整体点评总结
# 非常注重 CI/CD 和跨平台兼容性: 变量基本都使用了 ?=, 方便外部注入; 针对 Linux 和 Darwin 作了 CGO 的编译区分.
# 巧妙利用静态模式规则防止代码冗余: 没有傻傻地去写 make build-example1, make build-example2, 而是基于文件目录动态推导编译 Target, 这是高级 Makefile 非常典型的做法.
# 隔离的容器化构建: 把原本在宿主机上执行的命令, 平滑地映射到了 docker-xxx 目标上执行, 并处理好了文件权限(--user 映射)和缓存(挂载 .cache), 可以说是现代 Cloud Native 项目 Makefile 的模范写法.

print:
	@echo "DOCKER: "$(DOCKER)
	@echo "MKDIR: "$(MKDIR)
	@echo "CURDIR: "$(CURDIR)
	@echo "DIST_DIR: "$(DIST_DIR)
	@echo "DRIVER_NAME: "$(DRIVER_NAME)
	@echo "MODULE: "$(MODULE)
	@echo "REGISTRY: "$(REGISTRY)
	@echo "VERSION: "$(VERSION)
	@echo "GOLANG_VERSION: "$(GOLANG_VERSION)
	@echo "BUILDIMAGE_TAG: "$(BUILDIMAGE_TAG)
	@echo "BUILDIMAGE: "$(BUILDIMAGE)
	@echo "GIT_COMMIT: "$(GIT_COMMIT)
	@echo "IMAGE_NAME: "$(IMAGE_NAME)
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
	@echo "PREFIX: "$(PREFIX)
	@echo "EXTLDFLAGS: "$(EXTLDFLAGS)
	@echo "BUILDFLAGS: "$(BUILDFLAGS)
	@echo "TESTS_FOLDERS: "$(TESTS_FOLDERS)
	@echo "TEST_TARGETS: "$(TEST_TARGETS)
	@echo "COVERAGE_FILE: "$(COVERAGE_FILE)
	@echo "BUILD_DEVEL_IMAGE: "$(BUILD_DEVEL_IMAGE)
# $ make print
# DOCKER: docker
# MKDIR: mkdir
# CURDIR: /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin
# DIST_DIR: /Users/huzhi/work/code/go_code/ai/gpu/k8s-device-plugin/dist
# DRIVER_NAME: k8s-device-plugin
# MODULE: github.com/NVIDIA/k8s-device-plugin
# REGISTRY: nvcr.io/nvidia
# VERSION: v0.19.0
# GOLANG_VERSION: 1.26.1
# BUILDIMAGE_TAG: devel-go1.26.1
# BUILDIMAGE: k8s-device-plugin:devel-go1.26.1
# GIT_COMMIT: da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty
# IMAGE_NAME: nvcr.io/nvidia/k8s-device-plugin
# EXAMPLES:
# EXAMPLE_TARGETS:
# CMDS: config-manager gpu-feature-discovery mps-control-daemon nvidia-device-plugin
# CMD_TARGETS: cmd-config-manager cmd-gpu-feature-discovery cmd-mps-control-daemon cmd-nvidia-device-plugin
# CHECK_TARGETS: lint
# MAKE_TARGETS: binaries build check fmt lint-internal test examples cmds coverage generate vendor check-modules lint
# TARGETS: binaries build check fmt lint-internal test examples cmds coverage generate vendor check-modules lint cmd-config-manager cmd-gpu-feature-discovery cmd-mps-control-daemon cmd-nvidia-device-plugin
# DOCKER_TARGETS: docker-binaries docker-build docker-check docker-fmt docker-lint-internal docker-test docker-examples docker-cmds docker-coverage docker-generate docker-vendor docker-check-modules docker-lint docker-cmd-config-manager docker-cmd-gpu-feature-discovery docker-cmd-mps-control-daemon docker-cmd-nvidia-device-plugin
# CLI_VERSION: v0.19.0
# CLI_VERSION_PACKAGE: github.com/NVIDIA/k8s-device-plugin/internal/info
# PREFIX:
# EXTLDFLAGS: -Wl,-undefined,dynamic_lookup
# BUILDFLAGS: -ldflags -s -w '-extldflags=-Wl,-undefined,dynamic_lookup' -X github.com/NVIDIA/k8s-device-plugin/internal/info.gitCommit=da27a4645b9fe19276ff8fc9920a85a9f30d977d-dirty -X github.com/NVIDIA/k8s-device-plugin/internal/info.version=v0.19.0
# TESTS_FOLDERS: ./tests/ e2e helm vendor
# TEST_TARGETS: test-./tests/ test-e2e test-helm test-vendor
# COVERAGE_FILE: coverage.out
# BUILD_DEVEL_IMAGE:
# $
