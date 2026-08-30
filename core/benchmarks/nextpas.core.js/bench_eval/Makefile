PROGRAM := bench_eval
SOURCE  := bench_eval.lpr
CORE_ROOT := ../../..
BUILD_DIR := $(CORE_ROOT)/build/projects/nextpas.core.js/bench_eval
FPC ?= fpc
BASE_FPC_FLAGS ?= -MObjFPC -Sh -Sg -O2 -gl
FPC_FLAGS = $(BASE_FPC_FLAGS) -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
.PHONY: build run clean
build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)
run: build
	$(BUILD_DIR)/$(PROGRAM)
clean:
	rm -rf $(BUILD_DIR)
