# nextPas/core — test_glx_gl
.PHONY: all build run test clean

CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform/test_glx_gl
PROGRAM := test_glx_gl
SOURCE := test_glx_gl.lpr

FPC ?= fpc
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

clean:
	rm -rf $(BUILD_DIR)

all: test
