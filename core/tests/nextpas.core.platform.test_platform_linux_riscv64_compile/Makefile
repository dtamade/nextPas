FPC ?= fpc
CORE_ROOT := ../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.test_platform_linux_riscv64_compile
PROGRAM := test_platform_linux_riscv64_compile
SOURCE := $(PROGRAM).lpr
FPC_RTL ?= /opt/fpcupdeluxe/fpc/lib/fpc/3.3.1/units
CROSS_TOOLS ?= $(HOME)/bin
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -Priscv64
FPC_FLAGS += -Fu$(FPC_RTL)/riscv64-linux
FPC_FLAGS += -Fu$(FPC_RTL)/riscv64-linux/rtl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build test clean
build:
	@mkdir -p $(BUILD_DIR)
	PATH="$(CROSS_TOOLS):$$PATH" $(FPC) $(FPC_FLAGS) $(SOURCE)

test: build
	@echo "truth=forced-compile: riscv64"

clean:
	rm -rf $(BUILD_DIR)
