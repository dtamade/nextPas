PROGRAM := e2e_quic_h3

FPC ?= fpc

CORE_ROOT   := ../../..
MODULE_NAME := $(notdir $(abspath $(CURDIR)/..))
TEST_NAME   := $(notdir $(abspath $(CURDIR)))

SOURCE  ?= $(PROGRAM).lpr

BUILD_DIR ?= $(CORE_ROOT)/build/projects/$(MODULE_NAME)/$(TEST_NAME)

# 真机网络取证程序：-O2 无 heaptrc（时序保真）；不进默认 gate，手工运行
# 旗标与 tests/common.mk 对齐（仅去 -gh/-dHEAPTRC_ACTIVE），避免混旗标全量重编
FPC_FLAGS = -MObjFPC -Sh -Sg -O2 -gl -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run clean clean-src

clean-src:
	find $(CORE_ROOT)/src -maxdepth 1 -type f \( -name "*.ppu" -o -name "*.o" \) -delete 2>/dev/null || true

build: clean-src
	mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

clean: clean-src
	rm -rf $(BUILD_DIR)
