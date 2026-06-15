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
	@if command -v qemu-riscv64 >/dev/null 2>&1; then \
		QEMU_LD_PREFIX=/usr/riscv64-linux-gnu qemu-riscv64 $(BUILD_DIR)/$(PROGRAM); \
	else \
		echo "SKIP: qemu-riscv64 not available"; \
		exit 0; \
	fi

test: run

clean:
	rm -rf $(BUILD_DIR)
