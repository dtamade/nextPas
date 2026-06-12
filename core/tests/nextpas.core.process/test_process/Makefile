FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.process/test_process
PROGRAM := test_process
SOURCE := test_process.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
WINDOWS_COMPILE_FLAGS := -MObjFPC -Sh -O2 -gl -Cn -dNEXTPAS_FORCE_HOST_WINDOWS
WINDOWS_COMPILE_FLAGS += -FU$(BUILD_DIR)/win64-compile -FE$(BUILD_DIR)/win64-compile -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test test-windows-compile clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

test-windows-compile:
	@mkdir -p $(BUILD_DIR)/win64-compile
	$(FPC) $(WINDOWS_COMPILE_FLAGS) $(SOURCE)

clean:
	rm -rf $(BUILD_DIR)
