FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.mem/test_memory_manager_crt_compile_gate
PROGRAM := test_memory_manager_crt_compile_gate
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
COMPILE_ONLY_FLAGS ?= -Cn
CRT_FLAGS ?= -dNEXTPAS_CORE_CRT_ALLOCATOR

.PHONY: build test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(COMPILE_ONLY_FLAGS) $(CRT_FLAGS) $(SOURCE)

test: build

clean:
	rm -rf $(BUILD_DIR)
