FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.contracts/test_contracts
DEFAULT_DIR := $(BUILD_DIR)/default
ENABLED_DIR := $(BUILD_DIR)/enabled
PROGRAM := test_contracts
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build build-default build-enabled run test clean

build: build-default build-enabled

build-default:
	@mkdir -p $(DEFAULT_DIR)
	$(FPC) $(FPC_FLAGS) -FU$(DEFAULT_DIR) -FE$(DEFAULT_DIR) $(SOURCE)

build-enabled:
	@mkdir -p $(ENABLED_DIR)
	$(FPC) $(FPC_FLAGS) -dNEXTPAS_CORE_CONTRACTS -FU$(ENABLED_DIR) -FE$(ENABLED_DIR) $(SOURCE)

run: build
	$(DEFAULT_DIR)/$(PROGRAM)
	$(ENABLED_DIR)/$(PROGRAM) --contracts-enabled

test: run

clean:
	rm -rf $(BUILD_DIR)
