FPC ?= fpc
PYTHON ?= python3
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.net/test_platform_net
PROGRAM := test_platform_net
SOURCE := test_platform_net.lpr
CONTRACT_SCRIPT := check_platform_net_contract.py
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
COMPILE_ONLY_FLAGS ?= -Cn
FORCE_WINDOWS_FLAGS ?= -dNEXTPAS_FORCE_HOST_WINDOWS

.PHONY: build run test contract forced-windows-compile clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run forced-windows-compile contract

contract:
	$(PYTHON) $(CONTRACT_SCRIPT)

forced-windows-compile:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(COMPILE_ONLY_FLAGS) $(FORCE_WINDOWS_FLAGS) $(SOURCE)

clean:
	rm -rf $(BUILD_DIR)
