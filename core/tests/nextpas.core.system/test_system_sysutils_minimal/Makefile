FPC ?= fpc
CORE_ROOT := ../../..
REPO_ROOT := ../../../..

BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.system/test_system_sysutils_minimal
PROGRAM := test_system_sysutils_minimal
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

COMPILER_BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.system/test_sysutils_compiler_contract
COMPILER_SOURCE := $(REPO_ROOT)/compiler/tests/test_sysutils_createfmt_contract.pas
COMPILER_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
COMPILER_FLAGS += -FU$(COMPILER_BUILD_DIR) -FE$(COMPILER_BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
COMPILER_PROGRAM := $(COMPILER_BUILD_DIR)/test_sysutils_createfmt_contract

.PHONY: build run compiler-contract test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

compiler-contract:
	@mkdir -p $(COMPILER_BUILD_DIR)
	$(FPC) $(COMPILER_FLAGS) $(COMPILER_SOURCE)
	$(COMPILER_PROGRAM)

test: run compiler-contract

clean:
	rm -rf $(BUILD_DIR) $(COMPILER_BUILD_DIR)
