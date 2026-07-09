PROGRAM := bench_hashmap_read
COMPARISON := bench_hashmap_comparison
include ../../common.mk

.PHONY: comparison

comparison: clean-src
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(COMPARISON).lpr
	$(BUILD_DIR)/$(COMPARISON)
