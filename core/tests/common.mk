# common.mk — shared build rules for nextpas.core test fixtures
# =========================================================
# Usage in your Makefile:
#   PROGRAM := test_base
#   include ../../common.mk
#   FPC_FLAGS += -B           (optional extra flags AFTER include)

FPC ?= fpc

CORE_ROOT   := ../../..
MODULE_NAME := $(notdir $(abspath $(CURDIR)/..))
TEST_NAME   := $(notdir $(abspath $(CURDIR)))

PROGRAM ?= test_program
SOURCE  ?= $(PROGRAM).lpr

BUILD_DIR ?= $(CORE_ROOT)/build/projects/$(MODULE_NAME)/$(TEST_NAME)

FPC_FLAGS = -MObjFPC -Sh -O2 -gl -gh -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean clean-src

clean-src:
	@find $(CORE_ROOT)/src -maxdepth 1 -type f \( -name '*.ppu' -o -name '*.o' \) -delete 2>/dev/null || true

build: clean-src
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

clean: clean-src
	rm -rf $(BUILD_DIR)
