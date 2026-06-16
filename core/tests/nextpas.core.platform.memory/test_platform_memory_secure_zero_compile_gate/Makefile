FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.memory/test_platform_memory_secure_zero_compile_gate
PROGRAM := test_platform_memory_secure_zero_compile_gate
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -Cn
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build windows-compile posix-compile test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

windows-compile:
	@mkdir -p $(BUILD_DIR)/windows
	$(FPC) $(FPC_FLAGS) -dNEXTPAS_FORCE_HOST_WINDOWS -FU$(BUILD_DIR)/windows -FE$(BUILD_DIR)/windows $(SOURCE)
	@printf 'platform-memory-secure-zero-forced-compile-target=windows truth=source-contract status=pass\n'

posix-compile:
	@mkdir -p $(BUILD_DIR)/posix
	$(FPC) $(FPC_FLAGS) -dNEXTPAS_FORCE_HOST_UNIX -FU$(BUILD_DIR)/posix -FE$(BUILD_DIR)/posix $(SOURCE)
	@printf 'platform-memory-secure-zero-forced-compile-target=posix truth=source-contract status=pass\n'

test: build windows-compile posix-compile

clean:
	rm -rf $(BUILD_DIR)
