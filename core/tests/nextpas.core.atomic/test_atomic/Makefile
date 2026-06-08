FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.atomic/test_atomic
PROGRAM := test_atomic
SOURCE := $(PROGRAM).lpr
FORCED_COMPILE_SOURCE := test_atomic_forced_compile.lpr
EXTRA_FLAGS ?=
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh $(EXTRA_FLAGS)
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
FORCED_COMPILE_FLAGS ?= -B -MObjFPC -Sh -O2 -gl -Cn
FORCED_COMPILE_FLAGS += -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
HOST_COMPILE_FLAGS := $(FORCED_COMPILE_FLAGS) -FU$(BUILD_DIR)/compile-host -FE$(BUILD_DIR)/compile-host
WINDOWS_COMPILE_FLAGS := $(FORCED_COMPILE_FLAGS) -dNEXTPAS_FORCE_HOST_WINDOWS
WINDOWS_COMPILE_FLAGS += -FU$(BUILD_DIR)/compile-win64 -FE$(BUILD_DIR)/compile-win64
WIN64_FLAGS ?= -Twin64 -Px86_64

.PHONY: build run test compile-host cross-win64 print-architecture-truth test-forced-compile clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

compile-host:
	@mkdir -p $(BUILD_DIR)/compile-host
	$(FPC) $(HOST_COMPILE_FLAGS) $(FORCED_COMPILE_SOURCE)
	@printf 'atomic-forced-compile-target=host status=pass\n'

cross-win64:
	@mkdir -p $(BUILD_DIR)/compile-win64
	$(FPC) $(WINDOWS_COMPILE_FLAGS) $(WIN64_FLAGS) $(FORCED_COMPILE_SOURCE)
	@printf 'atomic-forced-compile-target=win64 status=pass\n'

print-architecture-truth:
	@printf 'atomic-architecture-truth-target=x86_64-linux status=focused-runtime-via-host-test runtime=true\n'
	@printf 'atomic-architecture-truth-target=win64 status=forced-compile-only runtime=false\n'
	@printf 'atomic-architecture-truth-target=i386 status=source-contract-only runtime=false\n'
	@printf 'atomic-architecture-truth-target=aarch64 status=source-contract-only runtime=false\n'
	@printf 'atomic-architecture-truth-target=arm status=source-contract-only runtime=false\n'
	@printf 'atomic-architecture-truth-target=riscv64 status=source-contract-only runtime=false\n'
	@printf 'atomic-architecture-truth-target=ppc status=source-contract-only runtime=false\n'
	@printf 'atomic-architecture-truth-target=ppc64 status=source-contract-only runtime=false\n'
	@printf 'atomic-architecture-truth-target=loongarch64 status=source-contract-only runtime=false\n'
	@printf 'atomic-forced-compile-matrix-compiled-targets=host,win64\n'

test-forced-compile: compile-host cross-win64 print-architecture-truth
	@printf 'atomic-forced-compile-matrix-status=pass\n'

clean:
	rm -rf $(BUILD_DIR)
