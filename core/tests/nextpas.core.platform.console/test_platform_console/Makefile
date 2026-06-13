FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.console/test_platform_console
PROGRAM := test_platform_console
SOURCE := test_platform_console.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
COMPILE_ONLY_FLAGS ?= -Cn
FORCE_WINDOWS_FLAGS ?= -dNEXTPAS_FORCE_HOST_WINDOWS

.PHONY: build run build-simulated-windows test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

build-simulated-windows:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(COMPILE_ONLY_FLAGS) $(FORCE_WINDOWS_FLAGS) $(SOURCE)

test: run build-simulated-windows

clean:
	rm -rf $(BUILD_DIR)
