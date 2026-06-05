FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform/test_platform_windows_utf16_compile_gate
PROGRAM := test_platform_windows_utf16_compile_gate
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
COMPILE_ONLY_FLAGS ?= -Cn
WIN64_FLAGS ?= -Twin64 -Px86_64

.PHONY: build cross-win64 test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(COMPILE_ONLY_FLAGS) $(SOURCE)

cross-win64:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(COMPILE_ONLY_FLAGS) $(WIN64_FLAGS) $(SOURCE)

test: build

clean:
	rm -rf $(BUILD_DIR)
