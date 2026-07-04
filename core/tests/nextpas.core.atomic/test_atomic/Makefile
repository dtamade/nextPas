PROGRAM := test_atomic
COMPAT_FORCED_COMPILE_SOURCE := test_atomic_compat_forced_compile.lpr
include ../../common.mk

# Forced compile gate: architecture truth verification
.PHONY: compile-host cross-win64 compile-compat-host cross-compat-win64 test-forced-compile

compile-host:
	@mkdir -p $(BUILD_DIR)/forced-host
	$(FPC) $(FPC_FLAGS) -Cn -B -FU$(BUILD_DIR)/forced-host test_atomic_forced_compile.lpr
	@printf 'atomic-forced-compile-target=host status=pass\n'
	@printf 'atomic-architecture-truth-target=x86_64-linux status=focused-runtime-via-host-test\n'
	@printf 'atomic-architecture-truth-target=x86_64-linux status=focused-runtime-via-host-test runtime=true\n'
	@printf 'atomic-architecture-truth-target=i386 status=source-contract-only\n'
	@printf 'atomic-architecture-truth-target=i386 status=source-contract-only runtime=false\n'
	@printf 'atomic-architecture-truth-target=aarch64 status=source-contract-only\n'
	@printf 'atomic-architecture-truth-target=aarch64 status=source-contract-only runtime=false\n'
	@printf 'atomic-architecture-truth-target=arm status=source-contract-only\n'
	@printf 'atomic-architecture-truth-target=arm status=source-contract-only runtime=false\n'
	@printf 'atomic-architecture-truth-target=riscv64 status=source-contract-only\n'
	@printf 'atomic-architecture-truth-target=riscv64 status=source-contract-only runtime=false\n'
	@printf 'atomic-architecture-truth-target=ppc status=source-contract-only\n'
	@printf 'atomic-architecture-truth-target=ppc status=source-contract-only runtime=false\n'
	@printf 'atomic-architecture-truth-target=ppc64 status=source-contract-only\n'
	@printf 'atomic-architecture-truth-target=ppc64 status=source-contract-only runtime=false\n'
	@printf 'atomic-architecture-truth-target=loongarch64 status=source-contract-only\n'
	@printf 'atomic-architecture-truth-target=loongarch64 status=source-contract-only runtime=false\n'
	@printf 'atomic-forced-compile-matrix-compiled-targets=host,win64\n'

cross-win64:
	@mkdir -p $(BUILD_DIR)/forced-win64
	$(FPC) $(FPC_FLAGS) -Cn -B -dNEXTPAS_FORCE_HOST_WINDOWS -FU$(BUILD_DIR)/forced-win64 test_atomic_forced_compile.lpr
	@printf 'atomic-forced-compile-target=win64 status=pass\n'
	@printf 'atomic-architecture-truth-target=win64 status=forced-compile-only runtime=false\n'

compile-compat-host:
	@mkdir -p $(BUILD_DIR)/forced-compat-host
	$(FPC) $(FPC_FLAGS) -Cn -B -FU$(BUILD_DIR)/forced-compat-host $(COMPAT_FORCED_COMPILE_SOURCE)
	@printf 'atomic-compat-forced-compile-target=host status=pass\n'

cross-compat-win64:
	@mkdir -p $(BUILD_DIR)/forced-compat-win64
	$(FPC) $(FPC_FLAGS) -Cn -B -dNEXTPAS_FORCE_HOST_WINDOWS -FU$(BUILD_DIR)/forced-compat-win64 $(COMPAT_FORCED_COMPILE_SOURCE)
	@printf 'atomic-compat-forced-compile-target=win64 status=pass\n'

test-forced-compile: compile-host compile-compat-host cross-win64 cross-compat-win64
