FPC ?= /opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
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

.PHONY: test test-vec test-algorithms test-all bench audit cpuinfo-focused cpuinfo-heaptrc cpuinfo-nonx86-compile clean

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

test-all: test test-vec audit cpuinfo-focused

audit:
	python3 $(CORE_ROOT)/tools/simdgen/simdgen.py --verify
	python3 $(CORE_ROOT)/tools/simdgen/simdgen_verify_slots.py
	python3 check_avx512_alignment_contract.py
	python3 check_simd_contract_roadmap.py
	python3 check_cpuinfo_boundary_contract.py

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
	rm -f $(BUILD_DIR)/$(RUNNER) $(BUILD_DIR)/$(VEC_TEST) $(BUILD_DIR)/$(ALG_TEST)
