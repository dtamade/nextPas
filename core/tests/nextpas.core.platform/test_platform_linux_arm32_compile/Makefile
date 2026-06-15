FPC ?= /opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.test_platform_linux_arm32_compile
PROGRAM := test_platform_linux_arm32_compile
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -Parm -Tlinux -MObjFPC -Sh -O2 -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	@$(FPC) -iTP 2>/dev/null | grep -q arm && { \
		$(FPC) $(FPC_FLAGS) $(SOURCE); \
	} || { \
		echo "SKIP: ppcrossarm not installed"; \
		echo "DOCUMENTED-GAP: FPC arm cross-compiler units not available"; \
		echo "  To enable: install fpc cross-compiler for arm"; \
		echo "  Run: fpcupdeluxe --only=arm-linux"; \
	}

run: build
	@if command -v qemu-arm >/dev/null 2>&1 && [ -f $(BUILD_DIR)/$(PROGRAM) ]; then \
		QEMU_LD_PREFIX=/usr/arm-linux-gnueabihf qemu-arm $(BUILD_DIR)/$(PROGRAM); \
	else \
		echo "SKIP: qemu-arm or binary not available"; \
		exit 0; \
	fi

test: run

clean:
	rm -rf $(BUILD_DIR)
