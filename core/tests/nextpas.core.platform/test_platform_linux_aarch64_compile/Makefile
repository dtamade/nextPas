FPC ?= /opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.test_platform_linux_aarch64_compile
PROGRAM := test_platform_linux_aarch64_compile
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -Paarch64 -Tlinux -MObjFPC -Sh -O2
FPC_FLAGS += -XPaarch64-linux-gnu-
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	@if command -v qemu-aarch64 >/dev/null 2>&1 && [ -f $(BUILD_DIR)/$(PROGRAM) ]; then \
		QEMU_LD_PREFIX=/usr/aarch64-linux-gnu qemu-aarch64 $(BUILD_DIR)/$(PROGRAM); \
	else \
		echo "SKIP: qemu-aarch64 or binary not available"; \
		exit 0; \
	fi

test: run

clean:
	rm -rf $(BUILD_DIR)
