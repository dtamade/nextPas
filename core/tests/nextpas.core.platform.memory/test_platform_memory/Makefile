FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.memory/test_platform_memory
PROGRAM := test_platform_memory
SOURCE := test_platform_memory.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run windows-compile test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

windows-compile:
	@mkdir -p $(BUILD_DIR)/windows
	$(FPC) $(FPC_FLAGS) -Cn -dNEXTPAS_FORCE_HOST_WINDOWS -FU$(BUILD_DIR)/windows -FE$(BUILD_DIR)/windows $(SOURCE)
	@printf 'platform-memory-forced-compile-target=windows truth=source-contract status=pass\n'

test: run windows-compile

clean:
	rm -rf $(BUILD_DIR)
