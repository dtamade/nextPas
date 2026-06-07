FPC ?= fpc
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.hash/test_wyhash
PROGRAM := test_wyhash
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM) 2>&1 | tee /tmp/test_wyhash_output.txt
	@grep -q "0 unfreed memory blocks" /tmp/test_wyhash_output.txt || (echo "LEAK DETECTED"; exit 1)

test: run

clean:
	rm -rf $(BUILD_DIR)
