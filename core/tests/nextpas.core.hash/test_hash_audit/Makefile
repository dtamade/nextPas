FPC ?= fpc
PYTHON ?= python3
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
CORE_ROOT := ../../..
REPO_ROOT := ../../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.hash/test_hash_audit
PROGRAM := test_hash_audit
SOURCE := $(PROGRAM).lpr
CONTRACT_SCRIPT := check_hash_util_contract.py
RUN_OUTPUT := $(BUILD_DIR)/$(PROGRAM)_output.txt
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(REPO_ROOT)/src -Fi$(REPO_ROOT)/src -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build source-contract run test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

source-contract:
	$(PYTHON) $(CONTRACT_SCRIPT)

run: build
	$(BUILD_DIR)/$(PROGRAM) 2>&1 | tee $(RUN_OUTPUT)
	@grep -Eq '^[[:space:]]*0[[:space:]]+unfreed[[:space:]]+memory[[:space:]]+blocks([[:space:]:]|$$)' $(RUN_OUTPUT) || (echo "LEAK DETECTED"; exit 1)

test: source-contract run

clean:
	rm -rf $(BUILD_DIR)
