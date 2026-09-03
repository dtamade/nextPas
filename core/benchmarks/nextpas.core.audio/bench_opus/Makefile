FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.audio/bench_opus
PROGRAM := bench_opus
SOURCE := bench_opus.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -Xs -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib
.PHONY: build run test bench clean
build:
	mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)
run: build
	$(BUILD_DIR)/$(PROGRAM)
test: run
bench: run
clean:
	rm -rf $(BUILD_DIR)
