FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.sync/test_platform_sync_posix_fallback
PROGRAM := test_platform_sync_posix_fallback
SOURCE := ../test_platform_sync/test_platform_sync.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl
FPC_FLAGS += -dNEXTPAS_PLATFORM_SYNC_FORCE_POSIX_WAIT_FALLBACK
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -o$(BUILD_DIR)/$(PROGRAM) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

clean:
	rm -rf $(BUILD_DIR)
