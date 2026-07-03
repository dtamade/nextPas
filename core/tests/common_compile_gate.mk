# common_compile_gate.mk — shared build rules for compile-only gate tests
# Tests verify cross-platform compilation succeeds without running the binary.
# Usage:
#   PROGRAM := test_foo
#   FPC_FLAGS += -dNEXTPAS_FORCE_HOST_WINDOWS
#   include ../../common_compile_gate.mk

FPC ?= fpc
CORE_ROOT   := ../../..
MODULE_NAME := $(notdir $(abspath $(CURDIR)/..))
TEST_NAME   := $(notdir $(abspath $(CURDIR)))
PROGRAM ?= test_program
SOURCE  ?= $(PROGRAM).lpr
BUILD_DIR ?= $(CORE_ROOT)/build/projects/$(MODULE_NAME)/$(TEST_NAME)
FPC_FLAGS = -MObjFPC -Sh -O2 -gl -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

test: build

clean:
	rm -rf $(BUILD_DIR)
