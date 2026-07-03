FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.mem/test_slab_thread_safety
PROGRAM := test_slab_thread_safety
SOURCE := $(PROGRAM).lpr
# -dDEBUG 启用 CS-017 跨线程检测
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -dDEBUG
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

clean:
	rm -rf $(BUILD_DIR)
