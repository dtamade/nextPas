PROGRAM := test_lockfree_hazard
include ../../common.mk

DEBUG_BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.lockfree/test_lockfree_hazard_debug
DEBUG_FPC_FLAGS = -MObjFPC -Sh -O2 -gl -gh -dDEBUG -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: test-debug clean-debug

test-debug: run-debug

run-debug:
	@mkdir -p $(DEBUG_BUILD_DIR)
	$(FPC) $(DEBUG_FPC_FLAGS) -FU$(DEBUG_BUILD_DIR) -FE$(DEBUG_BUILD_DIR) $(SOURCE)
	$(DEBUG_BUILD_DIR)/$(PROGRAM)

CLEAN_BUILD_DIRS := $(BUILD_DIR) $(DEBUG_BUILD_DIRS)

clean-debug:
	rm -rf $(DEBUG_BUILD_DIR)
