PROGRAM := test_lockfree
FACADE_FORCED_COMPILE_SOURCE := test_lockfree_facade_forced_compile.lpr
include ../../common.mk

DEBUG_BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.lockfree/test_lockfree_debug
DEBUG_FPC_FLAGS = -MObjFPC -Sh -O2 -gl -gh -dDEBUG -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

# Forced compile gate: facade-only verification
.PHONY: build run test compile-facade-host test-forced-compile test-debug clean

compile-facade-host:
	@mkdir -p $(BUILD_DIR)/facade-forced
	$(FPC) $(FPC_FLAGS) -Cn -B -FU$(BUILD_DIR)/facade-forced $(FACADE_FORCED_COMPILE_SOURCE)
	@printf 'lockfree-facade-forced-compile-target=host status=pass\n'
	@printf 'lockfree-forced-compile-status=pass\n'

test-forced-compile: compile-facade-host

test-debug: run-debug

run-debug:
	@mkdir -p $(DEBUG_BUILD_DIR)
	$(FPC) $(DEBUG_FPC_FLAGS) -FU$(DEBUG_BUILD_DIR) -FE$(DEBUG_BUILD_DIR) $(SOURCE)
	$(DEBUG_BUILD_DIR)/$(PROGRAM)

CLEAN_BUILD_DIRS := $(BUILD_DIR) $(DEBUG_BUILD_DIR)

clean:
	rm -rf $(CLEAN_BUILD_DIRS)

clean-debug:
	CLEAN_BUILD_DIRS := $(DEBUG_BUILD_DIR)
	rm -rf $(CLEAN_BUILD_DIRS)

clean-release:
	CLEAN_BUILD_DIRS := $(BUILD_DIR)
	rm -rf $(CLEAN_BUILD_DIRS)
