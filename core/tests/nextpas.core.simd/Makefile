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
EXPERIMENTAL_INTRINSICS_TEST_DIR := $(CORE_ROOT)/tests/nextpas.core.simd.intrinsics.experimental

.DEFAULT_GOAL := test

.PHONY: check coverage test test-vec test-algorithms api-coverage-contract api-coverage-refresh-checklist api-coverage-test api-coverage-heaptrc api-coverage-focused test-sse-raw test-sse-raw-heaptrc static-avx2-misalignment test-mmx-raw test-mmx-raw-heaptrc test-all bench-build bench audit audit-hygiene-contract cpuinfo-focused cpuinfo-heaptrc cpuinfo-nonx86-compile neon-optin-focused riscvv-facade-optin-compile experimental-intrinsics-tests experimental-intrinsics-focused experimental-intrinsics-closure clean

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
	@mkdir -p $(BUILD_DIR) $(API_COVERAGE_HEAPTRC_BUILD_DIR)
	@for l_test in $(API_COVERAGE_TESTS); do \
		mkdir -p $(API_COVERAGE_HEAPTRC_BUILD_DIR)/$$l_test; \
		$(FPC) $(FPC_FLAGS) -B -gh -FU$(API_COVERAGE_HEAPTRC_BUILD_DIR)/$$l_test -o$$l_test $$l_test.pas || exit $$?; \
		$(BUILD_DIR)/$$l_test || exit $$?; \
	done

api-coverage-focused: api-coverage-contract api-coverage-test api-coverage-heaptrc

test-sse-raw:
	@mkdir -p $(BUILD_DIR) $(SSE_RAW_BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B -FU$(SSE_RAW_BUILD_DIR) $(SSE_RAW_TEST).pas
	$(BUILD_DIR)/$(SSE_RAW_TEST)

test-sse-raw-heaptrc:
	@mkdir -p $(BUILD_DIR) $(SSE_RAW_HEAPTRC_BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B -gh -FU$(SSE_RAW_HEAPTRC_BUILD_DIR) -o$(SSE_RAW_TEST) $(SSE_RAW_TEST).pas
	$(BUILD_DIR)/$(SSE_RAW_TEST)

static-avx2-misalignment:
	@mkdir -p $(BUILD_DIR) $(STATIC_AVX2_MISALIGNMENT_BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B -gh -FU$(STATIC_AVX2_MISALIGNMENT_BUILD_DIR) -o$(STATIC_AVX2_USABLE_PROBE) $(STATIC_AVX2_USABLE_PROBE).pas
	@$(BUILD_DIR)/$(STATIC_AVX2_USABLE_PROBE); \
	l_status=$$?; \
	if [ $$l_status -eq 77 ]; then \
		exit 0; \
	elif [ $$l_status -ne 0 ]; then \
		exit $$l_status; \
	fi
	$(FPC) $(FPC_FLAGS) -B -gh -FU$(STATIC_AVX2_MISALIGNMENT_BUILD_DIR) -o$(STATIC_AVX2_MISALIGNMENT_TEST) $(STATIC_AVX2_MISALIGNMENT_TEST).pas
	$(BUILD_DIR)/$(STATIC_AVX2_MISALIGNMENT_TEST)

test-mmx-raw:
	@mkdir -p $(BUILD_DIR) $(MMX_RAW_BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B -FU$(MMX_RAW_BUILD_DIR) -o$(MMX_RAW_TEST) $(MMX_RAW_TEST_PROJECT)
	$(BUILD_DIR)/$(MMX_RAW_TEST)

test-mmx-raw-heaptrc:
	@mkdir -p $(BUILD_DIR) $(MMX_RAW_HEAPTRC_BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B -gh -FU$(MMX_RAW_HEAPTRC_BUILD_DIR) -o$(MMX_RAW_TEST) $(MMX_RAW_TEST_PROJECT)
	$(BUILD_DIR)/$(MMX_RAW_TEST)

test-all: test test-vec audit cpuinfo-focused

bench-build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B $(RUNNER).lpr

audit:
	$(PYTHON) $(CORE_ROOT)/tools/simdgen/simdgen.py --verify
	$(PYTHON) $(CORE_ROOT)/tools/simdgen/simdgen_verify_slots.py
	$(PYTHON) check_avx512_alignment_contract.py
	$(PYTHON) check_simd_contract_roadmap.py
	$(PYTHON) check_shell_runner_contract.py
	$(PYTHON) check_qemu_runner_contract.py
	$(PYTHON) check_intrinsics_coverage_layout_contract.py --summary-line
	$(PYTHON) check_riscvv_native_evidence_surface.py --summary-line
	$(PYTHON) check_linux_evidence_shell_surface.py --summary-line
	$(PYTHON) check_windows_freeze_shell_surface.py --summary-line
	$(PYTHON) check_nonx86_helper_semantics.py --summary-line
	$(PYTHON) check_static_avx2_misalignment_contract.py
	$(PYTHON) check_sse2_structure.py --summary-line
	$(PYTHON) check_intrinsics_experimental_status.py --summary-line
	$(PYTHON) check_dispatch_contract_signature.py --summary-line
	$(PYTHON) check_public_abi_signature.py --summary-line
	$(PYTHON) check_windows_publicabi_contract.py
	$(PYTHON) check_cpuinfo_runner_contract.py --summary-line
	$(PYTHON) check_cpuinfo_boundary_contract.py
	$(PYTHON) check_riscvv_facade_optin_contract.py --summary-line

audit-hygiene-contract:
	rm -rf $(CORE_ROOT)/tools/simdgen/__pycache__
	$(MAKE) audit
	$(MAKE) -C $(REPO_ROOT) hygiene

cpuinfo-focused: cpuinfo-heaptrc cpuinfo-nonx86-compile

cpuinfo-heaptrc:
	@mkdir -p $(BUILD_DIR) $(CORE_ROOT)/build/lib/cpuinfo-test
	$(FPC) $(CPUINFO_FPC_FLAGS) -gh -dSIMD_X86_AVAILABLE -Fu$(CPUINFO_TEST_DIR) -FU$(CORE_ROOT)/build/lib/cpuinfo-test -FE$(BUILD_DIR) -o$(CPUINFO_TEST_BIN) $(CPUINFO_TEST_DIR)/$(CPUINFO_TEST_BIN).lpr
	$(BUILD_DIR)/$(CPUINFO_TEST_BIN)

cpuinfo-nonx86-compile:
	@mkdir -p $(CORE_ROOT)/build/lib/cpuinfo-arm $(CORE_ROOT)/build/lib/cpuinfo-riscv $(CORE_ROOT)/build/lib/cpuinfo-loongarch
	$(FPC) $(CPUINFO_FPC_FLAGS) -dSIMD_ARM_AVAILABLE -FU$(CORE_ROOT)/build/lib/cpuinfo-arm $(CORE_ROOT)/src/nextpas.core.simd.cpuinfo.arm.pas
	$(FPC) $(CPUINFO_FPC_FLAGS) -dSIMD_RISCV_AVAILABLE -FU$(CORE_ROOT)/build/lib/cpuinfo-riscv $(CORE_ROOT)/src/nextpas.core.simd.cpuinfo.riscv.pas
	$(FPC) $(CPUINFO_FPC_FLAGS) -dSIMD_LOONGARCH_AVAILABLE -FU$(CORE_ROOT)/build/lib/cpuinfo-loongarch $(CORE_ROOT)/src/nextpas.core.simd.cpuinfo.loongarch.pas

neon-optin-focused:
	@mkdir -p $(BUILD_DIR) $(NEON_OPTIN_BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B -FU$(NEON_OPTIN_BUILD_DIR) -dNEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND -o$(NEON_OPTIN_RUNNER) $(RUNNER).lpr
	$(BUILD_DIR)/$(NEON_OPTIN_RUNNER) --no-bench --suite=TTestCase_DispatchAPI,TTestCase_PublicAbi

riscvv-facade-optin-compile:
	@mkdir -p $(BUILD_DIR) $(RISCVV_FACADE_OPTIN_BUILD_DIR) $(dir $(RISCVV_FACADE_OPTIN_LOG))
	$(PYTHON) check_riscvv_facade_optin_contract.py --summary-line
	$(FPC) $(FPC_FLAGS) -B -gh -dSIMD_RISCV_AVAILABLE -dSIMD_EXPERIMENTAL_RISCVV -FU$(RISCVV_FACADE_OPTIN_BUILD_DIR) -o$(RISCVV_FACADE_OPTIN_SMOKE) $(RISCVV_FACADE_OPTIN_SMOKE).pas
	$(BUILD_DIR)/$(RISCVV_FACADE_OPTIN_SMOKE) > $(RISCVV_FACADE_OPTIN_LOG) 2>&1
	@if grep -Eq '(^|[[:space:]])[1-9][0-9]* unfreed memory blocks' $(RISCVV_FACADE_OPTIN_LOG); then \
		echo "[LEAK] FAILED: heaptrc reported unfreed blocks"; \
		cat $(RISCVV_FACADE_OPTIN_LOG); \
		exit 1; \
	fi
	@echo "[LEAK] OK"

experimental-intrinsics-focused:
	$(MAKE) -C $(EXPERIMENTAL_INTRINSICS_TEST_DIR) test-all

experimental-intrinsics-tests:
	bash ./BuildOrTest.sh experimental-intrinsics-tests

experimental-intrinsics-closure:
	bash ./BuildOrTest.sh experimental-intrinsics-closure

bench: bench-build
	$(BUILD_DIR)/$(RUNNER) --bench-only --vector-asm

clean:
	rm -f $(BUILD_DIR)/$(RUNNER) $(BUILD_DIR)/$(VEC_TEST) $(BUILD_DIR)/$(ALG_TEST) $(API_COVERAGE_TEST_BINARIES) $(BUILD_DIR)/$(SSE_RAW_TEST) $(BUILD_DIR)/$(STATIC_AVX2_MISALIGNMENT_TEST) $(BUILD_DIR)/$(STATIC_AVX2_USABLE_PROBE) $(BUILD_DIR)/$(MMX_RAW_TEST) $(BUILD_DIR)/$(NEON_OPTIN_RUNNER) $(BUILD_DIR)/$(RISCVV_FACADE_OPTIN_SMOKE)
	rm -rf $(API_COVERAGE_BUILD_DIR) $(API_COVERAGE_HEAPTRC_BUILD_DIR) $(STATIC_AVX2_MISALIGNMENT_BUILD_DIR) $(NEON_OPTIN_BUILD_DIR) $(RISCVV_FACADE_OPTIN_BUILD_DIR)
