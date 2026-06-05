FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.simd/test_algorithms
PROGRAM := test_algorithms
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -B
FPC_FLAGS += -Fu$(CORE_ROOT)/src -Fu$(CORE_ROOT)/src/generated -Fu..
FPC_FLAGS += -Fi$(CORE_ROOT)/src -FU$(BUILD_DIR) -FE$(BUILD_DIR)

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM) --all --format=plainnotiming

test: run

clean:
	rm -rf $(BUILD_DIR)
