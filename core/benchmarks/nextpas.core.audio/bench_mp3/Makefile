FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.audio/bench_mp3
PROGRAM := bench_mp3
SOURCE := bench_mp3.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -Xs
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib
# mp3 decoder 含手写 DCT/合成汇编：FPC 3.3.1 在 -O3 下出现寄存器分配错译（与 aarch64 -O2 同类），bench 固定 -O2

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
