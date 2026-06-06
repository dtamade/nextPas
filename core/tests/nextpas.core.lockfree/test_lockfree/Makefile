FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.lockfree/test_lockfree
PROGRAM := test_lockfree
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
DEBUG_FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh -dDEBUG

.PHONY: build run test test-debug clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

build-debug:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(DEBUG_FPC_FLAGS) -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src $(SOURCE)

run-debug: build-debug
	$(BUILD_DIR)/$(PROGRAM)

test-debug: run-debug

clean:
	rm -rf $(BUILD_DIR)
