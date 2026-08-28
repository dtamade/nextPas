FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.audio/bench_mp3
PROGRAM := bench_mp3
SOURCE := bench_mp3.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O3 -Xs
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

.PHONY: build run test clean

build:
	mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)
	if [ -f mini.mp3 ]; then cp mini.mp3 $(BUILD_DIR)/mini.mp3; fi

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

clean:
	rm -rf $(BUILD_DIR)
