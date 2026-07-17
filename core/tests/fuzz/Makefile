# fuzz input parser — stdin harness for tui.input ParseOne
# Depth is tests/fuzz (not tests/<module>/<gate>), so paths differ from common.mk.

FPC := fpc
CORE_ROOT := ../..
BUILD_DIR := $(CORE_ROOT)/build/projects/fuzz/fuzz_input_parser
FPC_FLAGS := -MObjFPC -Sh -Sg -O2 -gl -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: test clean

test:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -o$(BUILD_DIR)/fuzz_input_parser fuzz_input_parser.lpr
	@# empty stdin exits 0; corpus exercise is opt-in for local fuzzing
	$(BUILD_DIR)/fuzz_input_parser </dev/null

clean:
	rm -rf $(BUILD_DIR)
	rm -f *.o *.ppu fuzz_input_parser
