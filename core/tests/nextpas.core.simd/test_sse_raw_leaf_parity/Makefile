# test_sse_raw_leaf_parity — compile-only test
FPC := fpc
CORE_ROOT := ../../..
BUILD_DIR := $(CORE_ROOT)/build/projects/nextpas.core.simd/test_sse_raw_leaf_parity
FPC_FLAGS := -MObjFPC -Sh -O2 -gl -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/src

.PHONY: test clean

test:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -FE$(BUILD_DIR) -FU$(BUILD_DIR) -o$(BUILD_DIR)/test_sse_raw_leaf_parity test_sse_raw_leaf_parity.lpr

clean:
	rm -rf $(BUILD_DIR)
