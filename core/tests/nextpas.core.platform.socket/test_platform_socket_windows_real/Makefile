# Test Platform Socket Windows Real
# 16 tests for platform.socket on real Windows

.PHONY: build clean

FPC ?= fpc
WINE ?= wine
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.socket/test_platform_socket_windows_real
WINE_BUILD_DIR := $(BUILD_DIR)_wine_win64
PROGRAM := test_platform_socket_windows_real
SOURCE := $(PROGRAM).lpr
BASE_FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS ?= $(BASE_FPC_FLAGS)
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
WINE_FPC_FLAGS ?= $(BASE_FPC_FLAGS) -Twin64 -Px86_64
WINE_FPC_FLAGS += -FU$(WINE_BUILD_DIR) -FE$(WINE_BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test wine-build wine-run clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

wine-build:
	@mkdir -p $(WINE_BUILD_DIR)
	$(FPC) $(WINE_FPC_FLAGS) $(SOURCE)

wine-run: wine-build
	$(WINE) $(WINE_BUILD_DIR)/$(PROGRAM).exe

clean:
	rm -rf $(BUILD_DIR) $(WINE_BUILD_DIR)
