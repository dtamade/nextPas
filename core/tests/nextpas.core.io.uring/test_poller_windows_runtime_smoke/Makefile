FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.io.uring/test_poller_windows_runtime_smoke
FORCE_WINDOWS_BUILD_DIR ?= $(BUILD_DIR)_forced_windows
PROGRAM := test_poller_windows_runtime_smoke
SOURCE := $(PROGRAM).lpr
BASE_FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS ?= $(BASE_FPC_FLAGS)
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
FORCE_WINDOWS_FPC_FLAGS ?= $(BASE_FPC_FLAGS)
FORCE_WINDOWS_FPC_FLAGS += -FU$(FORCE_WINDOWS_BUILD_DIR) -FE$(FORCE_WINDOWS_BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
COMPILE_ONLY_FLAGS ?= -Cn
FORCE_WINDOWS_FLAGS ?= -dNEXTPAS_FORCE_HOST_WINDOWS

.PHONY: build run test forced-windows-compile clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

forced-windows-compile:
	@mkdir -p $(FORCE_WINDOWS_BUILD_DIR)
	$(FPC) $(FORCE_WINDOWS_FPC_FLAGS) $(COMPILE_ONLY_FLAGS) $(FORCE_WINDOWS_FLAGS) $(SOURCE)

test: run forced-windows-compile

clean:
	rm -rf $(BUILD_DIR) $(FORCE_WINDOWS_BUILD_DIR)
