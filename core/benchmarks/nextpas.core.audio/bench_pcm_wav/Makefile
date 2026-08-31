FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.audio/bench_pcm_wav
PROGRAM := bench_pcm_wav
SOURCE := bench_pcm_wav.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O3 -Xs
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
