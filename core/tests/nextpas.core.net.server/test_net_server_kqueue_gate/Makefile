PROGRAM := test_net_server_kqueue_gate
FPC ?= fpc
CORE_ROOT   := ../../..
MODULE_NAME := $(notdir $(abspath $(CURDIR)/..))
TEST_NAME   := $(notdir $(abspath $(CURDIR)))
SOURCE  ?= $(PROGRAM).lpr
BUILD_DIR ?= $(CORE_ROOT)/build/projects/$(MODULE_NAME)/$(TEST_NAME)
FPC_BASE = -MObjFPC -Sh -O2 -gl -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Cn

.PHONY: darwin freebsd test clean build

# Darwin 强制编译是 kqueue 接线的编译证据（B8）；FreeBSD FORCE_HOST
# 受既有 platform.thread 类型阻碍（同 test_async_kqueue_compile_gate），
# 仅保留目标，不纳入 test。
darwin:
	@mkdir -p $(BUILD_DIR)/darwin
	$(FPC) $(FPC_BASE) -dNEXTPAS_FORCE_HOST_DARWIN -FU$(BUILD_DIR)/darwin -FE$(BUILD_DIR)/darwin $(SOURCE)
	@printf 'kqueue-compile-target=darwin status=pass\n'

freebsd:
	@mkdir -p $(BUILD_DIR)/freebsd
	$(FPC) $(FPC_BASE) -dNEXTPAS_FORCE_HOST_FREEBSD -FU$(BUILD_DIR)/freebsd -FE$(BUILD_DIR)/freebsd $(SOURCE)
	@printf 'kqueue-compile-target=freebsd status=pass\n'

test: darwin
	@printf 'kqueue-compile-gate=pass\n'

build: test

clean:
	rm -rf $(BUILD_DIR)