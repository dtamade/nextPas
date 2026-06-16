FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform/test_platform_io_windows_real
PROGRAM := test_platform_io_windows_real
SOURCE := $(PROGRAM).lpr
FPC_RTL ?= /opt/fpcupdeluxe/fpc/lib/fpc/3.3.1/units
CROSS_TOOLS ?= $(HOME)/bin
FPC_FLAGS ?= -Twin64 -Px86_64 -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -Fu$(FPC_RTL)/x86_64-win64
FPC_FLAGS += -Fu$(FPC_RTL)/x86_64-win64/rtl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	PATH="$(CROSS_TOOLS):$$PATH" $(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

clean:
	rm -rf $(BUILD_DIR)