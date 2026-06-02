FPC ?= fpc
CORE_ROOT := ../../..
REPO_ROOT := ../../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.git/test_git
PROGRAM := test_git
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(REPO_ROOT)/src -Fi$(REPO_ROOT)/src -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test build-static run-static test-static clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

build-static:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -dNEXTPAS_CORE_GIT_LIBGIT2_STATIC $(SOURCE)

run-static: build-static
	$(BUILD_DIR)/$(PROGRAM)

test-static: clean run-static

clean:
	rm -rf $(BUILD_DIR)
