FPC ?= /opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.test_platform_linux_riscv64_smoke
PROGRAM := test_platform_linux_riscv64_smoke
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -Priscv64 -Tlinux -MObjFPC -Sh -O2 -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	@echo "SKIP: runtime smoke deferred (compile gate only for now)"
	@exit 0

test: run

clean:
	rm -rf $(BUILD_DIR)
