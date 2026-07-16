# M3-4: cross-OS mem gate
#   - FORCE_HOST Windows / FreeBSD: compile-only (-Cn) for IFDEF type-check
#   - Host: full runtime smoke (alloc/free/arena) on the real OS
# Separate BUILD subdirs so FORCE_HOST objects cannot pollute host link.

FPC ?= fpc
CORE_ROOT := ../../..
BUILD_ROOT ?= $(CORE_ROOT)/build/projects/nextpas.core.mem/test_mem_cross_os_compile_gate
PROGRAM := test_mem_cross_os_compile_gate
SOURCE := $(PROGRAM).lpr
FPC_COMMON = -MObjFPC -Sh -O2 -gl -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
FPC_COMPILE_ONLY = $(FPC_COMMON) -Cn

.PHONY: build-windows build-freebsd host-runtime test clean

build-windows:
	@mkdir -p $(BUILD_ROOT)/windows
	$(FPC) $(FPC_COMPILE_ONLY) -FU$(BUILD_ROOT)/windows -FE$(BUILD_ROOT)/windows \
	  -dNEXTPAS_FORCE_HOST_WINDOWS $(SOURCE)

build-freebsd:
	@mkdir -p $(BUILD_ROOT)/freebsd
	$(FPC) $(FPC_COMPILE_ONLY) -FU$(BUILD_ROOT)/freebsd -FE$(BUILD_ROOT)/freebsd \
	  -dNEXTPAS_FORCE_HOST_FREEBSD $(SOURCE)

host-runtime:
	@mkdir -p $(BUILD_ROOT)/host
	$(FPC) $(FPC_COMMON) -gh -FU$(BUILD_ROOT)/host -FE$(BUILD_ROOT)/host $(SOURCE)
	$(BUILD_ROOT)/host/$(PROGRAM)

test: build-windows build-freebsd host-runtime

clean:
	rm -rf $(BUILD_ROOT)
