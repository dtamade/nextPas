FPC ?= /opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
CORE_ROOT := ../..
REPO_ROOT := $(abspath $(CORE_ROOT)/..)
BUILD_DIR := $(CORE_ROOT)/build/bin
PYTHON ?= python3 -B
FPC_FLAGS := -O3 -gl
FPC_FLAGS += -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/src -Fu$(CORE_ROOT)/src/generated -Fu.
FPC_FLAGS += -FE$(BUILD_DIR)
CPUINFO_TEST_DIR := $(CORE_ROOT)/tests/nextpas.core.simd.cpuinfo
CPUINFO_TEST_BIN := nextpas.core.simd.cpuinfo.test
CPUINFO_FPC_FLAGS := -B -Mobjfpc -Sc -Si -O2 -gl
CPUINFO_FPC_FLAGS += -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/src -Fu$(CORE_ROOT)/src/generated

BITOPS_TEST := test_bitops
RUNNER := nextpas.core.simd.test
VEC_TEST := test_vec_all
ALG_TEST := test_algorithms
API_COVERAGE_TESTS := \
	test_api_coverage_core_vectors \
	test_api_coverage_batch_math \
	test_api_coverage_gather_scatter \
	test_api_coverage_wide_vectors
API_COVERAGE_TEST_BINARIES := $(addprefix $(BUILD_DIR)/,$(API_COVERAGE_TESTS))
API_COVERAGE_BUILD_DIR := $(CORE_ROOT)/build/lib/test-api-coverage
API_COVERAGE_HEAPTRC_BUILD_DIR := $(CORE_ROOT)/build/lib/test-api-coverage-heaptrc
SSE_RAW_TEST := test_sse_raw_leaf_parity
SSE_RAW_BUILD_DIR := $(CORE_ROOT)/build/lib/sse-raw
SSE_RAW_HEAPTRC_BUILD_DIR := $(CORE_ROOT)/build/lib/sse-raw-heaptrc
STATIC_AVX2_MISALIGNMENT_TEST := test_static_avx2_misalignment
STATIC_AVX2_USABLE_PROBE := probe_static_avx2_usable
STATIC_AVX2_MISALIGNMENT_BUILD_DIR := $(CORE_ROOT)/build/lib/static-avx2-misalignment
MMX_RAW_TEST := test_mmx_raw_leaf_parity
MMX_RAW_TEST_PROJECT := test_mmx_raw_leaf_parity/test_mmx_raw_leaf_parity.lpr
MMX_RAW_BUILD_DIR := $(CORE_ROOT)/build/lib/mmx-raw
MMX_RAW_HEAPTRC_BUILD_DIR := $(CORE_ROOT)/build/lib/mmx-raw-heaptrc
NEON_OPTIN_RUNNER := nextpas.core.simd.test.neonoptin
NEON_OPTIN_BUILD_DIR := $(CORE_ROOT)/build/lib/simd-test-neon-optin
RISCVV_FACADE_OPTIN_SMOKE := nextpas.core.simd.riscvv_facade_optin_smoke
RISCVV_FACADE_OPTIN_BUILD_DIR := $(CORE_ROOT)/build/lib/simd-riscvv-facade-optin
RISCVV_FACADE_OPTIN_LOG := $(CORE_ROOT)/build/tests/nextpas.core.simd/riscvv_facade_optin_smoke.txt
CONCURRENT_HEAPTRC_RUNNER := nextpas.core.simd.test.concurrentheaptrc
CONCURRENT_HEAPTRC_BUILD_DIR := $(CORE_ROOT)/build/lib/simd-test-concurrent-heaptrc
CONCURRENT_HEAPTRC_LOG := $(CORE_ROOT)/build/tests/nextpas.core.simd/concurrent_heaptrc.txt
CONCURRENT_SUITES := TTestCase_DirectDispatchConcurrent,TTestCase_SimdConcurrent,TTestCase_SimdConcurrentPublicAbi,TTestCase_SimdConcurrentFramework,TTestCase_SimdConcurrentRegistration
CONCURRENT_SUITE_COUNT := 5
EXPERIMENTAL_INTRINSICS_TEST_DIR := $(CORE_ROOT)/tests/nextpas.core.simd.intrinsics.experimental

# FPC trunk 3.3.1-19195 never delivers the heaptrc exit dump to the program's
# stderr/stdout (the log= file channel and the haltonnotreleased exit-code-203
# channel both work), so any leak gate that greps program output is vacuous.
# Every -gh run below therefore sets HEAPTRC=haltonnotreleased,log=<dump>:
# unfreed blocks fail the run with exit 203, and HEAPTRC_PINS requires the dump
# file to exist with an explicit "0 unfreed" line to prove heaptrc actually ran.
HEAPTRC_OPTS := haltonnotreleased
HEAPTRC_DUMP_DIR := $(CORE_ROOT)/build/tests/nextpas.core.simd
HEAPTRC_PINS = if ! grep -q '^Heap dump by heaptrc unit' $(1); then echo "[HEAPTRC] FAILED: no heap dump in $(1) (heaptrc vacuous?)"; exit 1; fi; if ! grep -q '^0 unfreed memory blocks : 0$$' $(1); then echo "[HEAPTRC] FAILED: unfreed blocks reported"; cat $(1); exit 1; fi; echo "[HEAPTRC] OK $(1)"

.DEFAULT_GOAL := test

.PHONY: check coverage test test-vec test-algorithms api-coverage-contract api-coverage-refresh-checklist api-coverage-test api-coverage-heaptrc api-coverage-focused test-sse-raw test-sse-raw-heaptrc static-avx2-misalignment test-mmx-raw test-mmx-raw-heaptrc test-all bench-build bench audit audit-hygiene-contract cpuinfo-focused cpuinfo-heaptrc cpuinfo-nonx86-compile neon-optin-focused riscvv-facade-optin-compile concurrent-heaptrc experimental-intrinsics-tests experimental-intrinsics-focused experimental-intrinsics-closure clean

check:
	bash ./BuildOrTest.sh check

coverage:
	bash ./BuildOrTest.sh coverage

test:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B $(RUNNER).lpr
	$(BUILD_DIR)/$(RUNNER) --no-bench

test-vec:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B $(VEC_TEST).pas
	$(BUILD_DIR)/$(VEC_TEST)

test-algorithms:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B $(ALG_TEST).lpr
	$(BUILD_DIR)/$(ALG_TEST) --all --format=plainnotiming

test-bitops:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B $(BITOPS_TEST).lpr
	$(BUILD_DIR)/$(BITOPS_TEST)

api-coverage-contract:
	$(PYTHON) check_public_api_test_coverage.py --summary-line --strict-thin
	$(PYTHON) check_direct_dispatch_scope.py --summary-line

api-coverage-refresh-checklist:
	$(PYTHON) generate_interface_checklist_v2.py

api-coverage-test:
	@mkdir -p $(BUILD_DIR) $(API_COVERAGE_BUILD_DIR)
	@for l_test in $(API_COVERAGE_TESTS); do \
		mkdir -p $(API_COVERAGE_BUILD_DIR)/$$l_test; \
		$(FPC) $(FPC_FLAGS) -B -FU$(API_COVERAGE_BUILD_DIR)/$$l_test -o$$l_test $$l_test.pas || exit $$?; \
		$(BUILD_DIR)/$$l_test || exit $$?; \
	done

api-coverage-heaptrc:
	@mkdir -p $(BUILD_DIR) $(API_COVERAGE_HEAPTRC_BUILD_DIR) $(HEAPTRC_DUMP_DIR)
	@for l_test in $(API_COVERAGE_TESTS); do \
		mkdir -p $(API_COVERAGE_HEAPTRC_BUILD_DIR)/$$l_test; \
		$(FPC) $(FPC_FLAGS) -B -gh -FU$(API_COVERAGE_HEAPTRC_BUILD_DIR)/$$l_test -o$$l_test $$l_test.pas || exit $$?; \
		rm -f $(HEAPTRC_DUMP_DIR)/$$l_test.heaptrc; \
		HEAPTRC='$(HEAPTRC_OPTS),log=$(HEAPTRC_DUMP_DIR)/'$$l_test.heaptrc $(BUILD_DIR)/$$l_test || exit $$?; \
		$(call HEAPTRC_PINS,$(HEAPTRC_DUMP_DIR)/$$l_test.heaptrc); \
	done

api-coverage-focused: api-coverage-contract api-coverage-test api-coverage-heaptrc

test-sse-raw:
	@mkdir -p $(BUILD_DIR) $(SSE_RAW_BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B -FU$(SSE_RAW_BUILD_DIR) $(SSE_RAW_TEST).pas
	$(BUILD_DIR)/$(SSE_RAW_TEST)

test-sse-raw-heaptrc:
	@mkdir -p $(BUILD_DIR) $(SSE_RAW_HEAPTRC_BUILD_DIR) $(HEAPTRC_DUMP_DIR)
	$(FPC) $(FPC_FLAGS) -B -gh -FU$(SSE_RAW_HEAPTRC_BUILD_DIR) -o$(SSE_RAW_TEST) $(SSE_RAW_TEST).pas
	@rm -f $(HEAPTRC_DUMP_DIR)/$(SSE_RAW_TEST).heaptrc
	HEAPTRC='$(HEAPTRC_OPTS),log=$(HEAPTRC_DUMP_DIR)/$(SSE_RAW_TEST).heaptrc' $(BUILD_DIR)/$(SSE_RAW_TEST)
	@$(call HEAPTRC_PINS,$(HEAPTRC_DUMP_DIR)/$(SSE_RAW_TEST).heaptrc)

static-avx2-misalignment:
	@mkdir -p $(BUILD_DIR) $(STATIC_AVX2_MISALIGNMENT_BUILD_DIR) $(HEAPTRC_DUMP_DIR)
	$(FPC) $(FPC_FLAGS) -B -gh -FU$(STATIC_AVX2_MISALIGNMENT_BUILD_DIR) -o$(STATIC_AVX2_USABLE_PROBE) $(STATIC_AVX2_USABLE_PROBE).pas
	@HEAPTRC='$(HEAPTRC_OPTS)' $(BUILD_DIR)/$(STATIC_AVX2_USABLE_PROBE); \
	l_status=$$?; \
	if [ $$l_status -eq 77 ]; then \
		exit 0; \
	elif [ $$l_status -ne 0 ]; then \
		exit $$l_status; \
	fi
	$(FPC) $(FPC_FLAGS) -B -gh -FU$(STATIC_AVX2_MISALIGNMENT_BUILD_DIR) -o$(STATIC_AVX2_MISALIGNMENT_TEST) $(STATIC_AVX2_MISALIGNMENT_TEST).pas
	@rm -f $(HEAPTRC_DUMP_DIR)/$(STATIC_AVX2_MISALIGNMENT_TEST).heaptrc
	HEAPTRC='$(HEAPTRC_OPTS),log=$(HEAPTRC_DUMP_DIR)/$(STATIC_AVX2_MISALIGNMENT_TEST).heaptrc' $(BUILD_DIR)/$(STATIC_AVX2_MISALIGNMENT_TEST)
	@$(call HEAPTRC_PINS,$(HEAPTRC_DUMP_DIR)/$(STATIC_AVX2_MISALIGNMENT_TEST).heaptrc)

test-mmx-raw:
	@mkdir -p $(BUILD_DIR) $(MMX_RAW_BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B -FU$(MMX_RAW_BUILD_DIR) -o$(MMX_RAW_TEST) $(MMX_RAW_TEST_PROJECT)
	$(BUILD_DIR)/$(MMX_RAW_TEST)

test-mmx-raw-heaptrc:
	@mkdir -p $(BUILD_DIR) $(MMX_RAW_HEAPTRC_BUILD_DIR) $(HEAPTRC_DUMP_DIR)
	$(FPC) $(FPC_FLAGS) -B -gh -FU$(MMX_RAW_HEAPTRC_BUILD_DIR) -o$(MMX_RAW_TEST) $(MMX_RAW_TEST_PROJECT)
	@rm -f $(HEAPTRC_DUMP_DIR)/$(MMX_RAW_TEST).heaptrc
	HEAPTRC='$(HEAPTRC_OPTS),log=$(HEAPTRC_DUMP_DIR)/$(MMX_RAW_TEST).heaptrc' $(BUILD_DIR)/$(MMX_RAW_TEST)
	@$(call HEAPTRC_PINS,$(HEAPTRC_DUMP_DIR)/$(MMX_RAW_TEST).heaptrc)

test-all: test test-vec audit cpuinfo-focused

bench-build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B $(RUNNER).lpr

# audit runs every step and only fails at the end, so one broken checker can
# never mask the rest (M3.4: a first-step failure hid 13 downstream failures).
audit:
	@l_fails=0; \
	step() { l_desc="$$1"; shift; \
	  if "$$@"; then echo "[audit] PASS $$l_desc"; \
	  else echo "[audit] FAIL $$l_desc"; l_fails=$$((l_fails+1)); fi; }; \
	step simdgen-verify $(PYTHON) $(CORE_ROOT)/tools/simdgen/simdgen.py --verify; \
	step simdgen-verify-slots $(PYTHON) $(CORE_ROOT)/tools/simdgen/simdgen_verify_slots.py; \
	step avx512-alignment $(PYTHON) check_avx512_alignment_contract.py; \
	step contract-roadmap $(PYTHON) check_simd_contract_roadmap.py; \
	step shell-runner $(PYTHON) check_shell_runner_contract.py; \
	step qemu-runner $(PYTHON) check_qemu_runner_contract.py; \
	step intrinsics-coverage-layout $(PYTHON) check_intrinsics_coverage_layout_contract.py --summary-line; \
	step riscvv-native-evidence $(PYTHON) check_riscvv_native_evidence_surface.py --summary-line; \
	step linux-evidence-shell $(PYTHON) check_linux_evidence_shell_surface.py --summary-line; \
	step windows-freeze-shell $(PYTHON) check_windows_freeze_shell_surface.py --summary-line; \
	step nonx86-helper-semantics $(PYTHON) check_nonx86_helper_semantics.py --summary-line; \
	step static-avx2-misalignment $(PYTHON) check_static_avx2_misalignment_contract.py; \
	step sse2-structure $(PYTHON) check_sse2_structure.py --summary-line; \
	step intrinsics-experimental $(PYTHON) check_intrinsics_experimental_status.py --summary-line; \
	step dispatch-signature $(PYTHON) check_dispatch_contract_signature.py --summary-line; \
	step public-abi-signature $(PYTHON) check_public_abi_signature.py --summary-line; \
	step windows-publicabi $(PYTHON) check_windows_publicabi_contract.py; \
	step cpuinfo-runner $(PYTHON) check_cpuinfo_runner_contract.py --summary-line; \
	step cpuinfo-boundary $(PYTHON) check_cpuinfo_boundary_contract.py; \
	step rtl-isolation $(PYTHON) ../nextpas.core.math/test_rtl_isolation/check_rtl_isolation.py --root $(CORE_ROOT) --fail-tests --summary-line; \
	step math-simd-source-contracts $(PYTHON) check_math_simd_source_contracts.py --root $(CORE_ROOT) --summary-line; \
	step riscvv-facade-optin $(PYTHON) check_riscvv_facade_optin_contract.py --summary-line; \
	echo "[audit] failures: $$l_fails/22"; \
	test $$l_fails -eq 0

audit-hygiene-contract:
	rm -rf $(CORE_ROOT)/tools/simdgen/__pycache__
	$(MAKE) audit
	$(MAKE) -C $(REPO_ROOT) hygiene

cpuinfo-focused: cpuinfo-heaptrc cpuinfo-nonx86-compile

cpuinfo-heaptrc:
	@mkdir -p $(BUILD_DIR) $(CORE_ROOT)/build/lib/cpuinfo-test $(HEAPTRC_DUMP_DIR)
	$(FPC) $(CPUINFO_FPC_FLAGS) -gh -dSIMD_X86_AVAILABLE -Fu$(CPUINFO_TEST_DIR) -FU$(CORE_ROOT)/build/lib/cpuinfo-test -FE$(BUILD_DIR) -o$(CPUINFO_TEST_BIN) $(CPUINFO_TEST_DIR)/$(CPUINFO_TEST_BIN).lpr
	@rm -f $(HEAPTRC_DUMP_DIR)/$(CPUINFO_TEST_BIN).heaptrc
	HEAPTRC='$(HEAPTRC_OPTS),log=$(HEAPTRC_DUMP_DIR)/$(CPUINFO_TEST_BIN).heaptrc' $(BUILD_DIR)/$(CPUINFO_TEST_BIN)
	@$(call HEAPTRC_PINS,$(HEAPTRC_DUMP_DIR)/$(CPUINFO_TEST_BIN).heaptrc)

cpuinfo-nonx86-compile:
	@mkdir -p $(CORE_ROOT)/build/lib/cpuinfo-arm $(CORE_ROOT)/build/lib/cpuinfo-riscv $(CORE_ROOT)/build/lib/cpuinfo-loongarch
	$(FPC) $(CPUINFO_FPC_FLAGS) -dSIMD_ARM_AVAILABLE -FU$(CORE_ROOT)/build/lib/cpuinfo-arm $(CORE_ROOT)/src/nextpas.core.simd.cpuinfo.arm.pas
	$(FPC) $(CPUINFO_FPC_FLAGS) -dSIMD_RISCV_AVAILABLE -FU$(CORE_ROOT)/build/lib/cpuinfo-riscv $(CORE_ROOT)/src/nextpas.core.simd.cpuinfo.riscv.pas
	$(FPC) $(CPUINFO_FPC_FLAGS) -dSIMD_LOONGARCH_AVAILABLE -FU$(CORE_ROOT)/build/lib/cpuinfo-loongarch $(CORE_ROOT)/src/nextpas.core.simd.cpuinfo.loongarch.pas

neon-optin-focused:
	@mkdir -p $(BUILD_DIR) $(NEON_OPTIN_BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B -FU$(NEON_OPTIN_BUILD_DIR) -dNEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND -o$(NEON_OPTIN_RUNNER) $(RUNNER).lpr
	$(BUILD_DIR)/$(NEON_OPTIN_RUNNER) --no-bench --suite=TTestCase_DispatchAPI,TTestCase_DispatchAPIControlPlane,TTestCase_DispatchAPIParity,TTestCase_DispatchAPIBatchParity,TTestCase_DispatchAPICapabilities,NonX86BackendParity,TTestCase_PublicAbi

riscvv-facade-optin-compile:
	@mkdir -p $(BUILD_DIR) $(RISCVV_FACADE_OPTIN_BUILD_DIR) $(dir $(RISCVV_FACADE_OPTIN_LOG))
	$(PYTHON) check_riscvv_facade_optin_contract.py --summary-line
	$(FPC) $(FPC_FLAGS) -B -gh -dSIMD_RISCV_AVAILABLE -dSIMD_EXPERIMENTAL_RISCVV -FU$(RISCVV_FACADE_OPTIN_BUILD_DIR) -o$(RISCVV_FACADE_OPTIN_SMOKE) $(RISCVV_FACADE_OPTIN_SMOKE).pas
	@rm -f $(RISCVV_FACADE_OPTIN_LOG).heaptrc
	HEAPTRC='$(HEAPTRC_OPTS),log=$(RISCVV_FACADE_OPTIN_LOG).heaptrc' $(BUILD_DIR)/$(RISCVV_FACADE_OPTIN_SMOKE) > $(RISCVV_FACADE_OPTIN_LOG) 2>&1
	@$(call HEAPTRC_PINS,$(RISCVV_FACADE_OPTIN_LOG).heaptrc)

# F-009 slice: concurrent suites run leak-checked on demand; default test stays
# heaptrc-free. The suite-count pin fails closed if the --suite filter matches
# nothing (typo) or a new concurrent suite is not added to CONCURRENT_SUITES.
concurrent-heaptrc:
	@mkdir -p $(BUILD_DIR) $(CONCURRENT_HEAPTRC_BUILD_DIR) $(dir $(CONCURRENT_HEAPTRC_LOG))
	$(FPC) $(FPC_FLAGS) -B -gh -dSIMD_X86_AVAILABLE -FU$(CONCURRENT_HEAPTRC_BUILD_DIR) -o$(CONCURRENT_HEAPTRC_RUNNER) $(RUNNER).lpr
	@rm -f $(CONCURRENT_HEAPTRC_LOG).heaptrc
	@if ! HEAPTRC='$(HEAPTRC_OPTS),log=$(CONCURRENT_HEAPTRC_LOG).heaptrc' $(BUILD_DIR)/$(CONCURRENT_HEAPTRC_RUNNER) --no-bench --suite=$(CONCURRENT_SUITES) > $(CONCURRENT_HEAPTRC_LOG) 2>&1; then \
		echo "[CONCURRENT-HEAPTRC] FAILED: runner exited non-zero (203 = unfreed blocks)"; \
		tail -40 $(CONCURRENT_HEAPTRC_LOG); \
		cat $(CONCURRENT_HEAPTRC_LOG).heaptrc 2>/dev/null; \
		exit 1; \
	fi
	@if ! grep -Eq '^ *Suites: $(CONCURRENT_SUITE_COUNT)$$' $(CONCURRENT_HEAPTRC_LOG); then \
		echo "[CONCURRENT-HEAPTRC] FAILED: expected Suites: $(CONCURRENT_SUITE_COUNT) (suite filter drifted?)"; \
		cat $(CONCURRENT_HEAPTRC_LOG); \
		exit 1; \
	fi
	@$(call HEAPTRC_PINS,$(CONCURRENT_HEAPTRC_LOG).heaptrc)

experimental-intrinsics-focused:
	$(MAKE) -C $(EXPERIMENTAL_INTRINSICS_TEST_DIR) test-all

experimental-intrinsics-tests:
	bash ./BuildOrTest.sh experimental-intrinsics-tests

experimental-intrinsics-closure:
	bash ./BuildOrTest.sh experimental-intrinsics-closure

bench: bench-build
	$(BUILD_DIR)/$(RUNNER) --bench-only --vector-asm

clean:
	rm -f $(BUILD_DIR)/$(RUNNER) $(BUILD_DIR)/$(VEC_TEST) $(BUILD_DIR)/$(ALG_TEST) $(API_COVERAGE_TEST_BINARIES) $(BUILD_DIR)/$(SSE_RAW_TEST) $(BUILD_DIR)/$(STATIC_AVX2_MISALIGNMENT_TEST) $(BUILD_DIR)/$(STATIC_AVX2_USABLE_PROBE) $(BUILD_DIR)/$(MMX_RAW_TEST) $(BUILD_DIR)/$(NEON_OPTIN_RUNNER) $(BUILD_DIR)/$(RISCVV_FACADE_OPTIN_SMOKE) $(BUILD_DIR)/$(CONCURRENT_HEAPTRC_RUNNER)
	rm -rf $(API_COVERAGE_BUILD_DIR) $(API_COVERAGE_HEAPTRC_BUILD_DIR) $(STATIC_AVX2_MISALIGNMENT_BUILD_DIR) $(NEON_OPTIN_BUILD_DIR) $(RISCVV_FACADE_OPTIN_BUILD_DIR) $(CONCURRENT_HEAPTRC_BUILD_DIR)
