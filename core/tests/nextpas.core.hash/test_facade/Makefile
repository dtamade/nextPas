FPC ?= fpc
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
CORE_ROOT := ../../..
REPO_ROOT := ../../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.hash/test_facade
PROGRAM := test_facade
SOURCE := $(PROGRAM).lpr
RUN_OUTPUT := $(BUILD_DIR)/$(PROGRAM)_output.txt
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(REPO_ROOT)/src -Fi$(REPO_ROOT)/src -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM) 2>&1 | tee $(RUN_OUTPUT)
	@grep -Eq '^[[:space:]]*0[[:space:]]+unfreed[[:space:]]+memory[[:space:]]+blocks([[:space:]:]|$$)' $(RUN_OUTPUT) || (echo "LEAK DETECTED"; exit 1)

test: run

clean:
	rm -rf $(BUILD_DIR)
