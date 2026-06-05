FPC ?= /opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
CORE_ROOT := ../..
BUILD_DIR := $(CORE_ROOT)/build/bin
FPC_FLAGS := -O3 -gl
FPC_FLAGS += -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/src -Fu$(CORE_ROOT)/src/generated -Fu.
FPC_FLAGS += -FE$(BUILD_DIR)

RUNNER := nextpas.core.simd.test
VEC_TEST := test_vec_all
ALG_TEST := test_algorithms

.PHONY: test test-vec test-algorithms test-all bench audit clean

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

test-all: test test-vec audit

audit:
	python3 $(CORE_ROOT)/tools/simdgen/simdgen.py --verify
	python3 $(CORE_ROOT)/tools/simdgen/simdgen_verify_slots.py
	python3 check_avx512_alignment_contract.py
	python3 check_simd_contract_roadmap.py

bench:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -B $(RUNNER).lpr
	$(BUILD_DIR)/$(RUNNER) --bench-only --vector-asm

clean:
	rm -f $(BUILD_DIR)/$(RUNNER) $(BUILD_DIR)/$(VEC_TEST) $(BUILD_DIR)/$(ALG_TEST)
