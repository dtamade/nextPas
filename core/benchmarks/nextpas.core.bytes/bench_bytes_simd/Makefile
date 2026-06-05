FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.bytes/bench_bytes_simd
PROGRAM := bench_bytes_simd
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -B
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

clean:
	rm -rf $(BUILD_DIR)
