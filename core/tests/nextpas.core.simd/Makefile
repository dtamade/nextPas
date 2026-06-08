FPC ?= /opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
PYTHON ?= python3 -B
CORE_ROOT := ../..
BUILD_DIR := $(CORE_ROOT)/build/bin
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
STATIC_AVX2_MISALIGNMENT_TEST := test_static_avx2_misalignment
STATIC_AVX2_USABLE_PROBE := probe_static_avx2_usable
STATIC_AVX2_MISALIGNMENT_BUILD_DIR := $(CORE_ROOT)/build/lib/static-avx2-misalignment

.PHONY: test test-vec test-algorithms static-avx2-misalignment test-all bench audit cpuinfo-focused cpuinfo-heaptrc cpuinfo-nonx86-compile clean

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

test-all: test test-vec audit cpuinfo-focused

audit:
	$(PYTHON) $(CORE_ROOT)/tools/simdgen/simdgen.py --verify
	$(PYTHON) $(CORE_ROOT)/tools/simdgen/simdgen_verify_slots.py
	$(PYTHON) check_avx512_alignment_contract.py
	$(PYTHON) check_simd_contract_roadmap.py
	$(PYTHON) check_static_avx2_misalignment_contract.py
	$(PYTHON) check_public_facade_scalar_fallback_contract.py
	$(PYTHON) check_cpuinfo_boundary_contract.py

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

bench:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B $(RUNNER).lpr
	$(BUILD_DIR)/$(RUNNER) --bench-only --vector-asm

clean:
	rm -f $(BUILD_DIR)/$(RUNNER) $(BUILD_DIR)/$(VEC_TEST) $(BUILD_DIR)/$(ALG_TEST) $(BUILD_DIR)/$(STATIC_AVX2_MISALIGNMENT_TEST) $(BUILD_DIR)/$(STATIC_AVX2_USABLE_PROBE)
	rm -rf $(STATIC_AVX2_MISALIGNMENT_BUILD_DIR)
