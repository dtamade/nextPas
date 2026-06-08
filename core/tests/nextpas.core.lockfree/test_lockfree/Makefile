FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.lockfree/test_lockfree
DEBUG_BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.lockfree/test_lockfree_debug
PROGRAM := test_lockfree
SOURCE := $(PROGRAM).lpr
FACADE_FORCED_COMPILE_SOURCE := test_lockfree_facade_forced_compile.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
FORCED_COMPILE_FLAGS ?= -B -MObjFPC -Sh -O2 -gl -Cn
FORCED_COMPILE_FLAGS += -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
FACADE_HOST_COMPILE_FLAGS := $(FORCED_COMPILE_FLAGS) -FU$(BUILD_DIR)/compile-facade-host -FE$(BUILD_DIR)/compile-facade-host
DEBUG_FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh -dDEBUG

CLEAN_BUILD_DIRS := $(BUILD_DIR) $(DEBUG_BUILD_DIR)
ifneq ($(filter build run test,$(MAKECMDGOALS)),)
  CLEAN_BUILD_DIRS := $(BUILD_DIR)
endif
ifneq ($(filter build-debug run-debug test-debug,$(MAKECMDGOALS)),)
  CLEAN_BUILD_DIRS := $(DEBUG_BUILD_DIR)
endif

.PHONY: build run test compile-facade-host test-forced-compile test-debug clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

compile-facade-host:
	@mkdir -p $(BUILD_DIR)/compile-facade-host
	$(FPC) $(FACADE_HOST_COMPILE_FLAGS) $(FACADE_FORCED_COMPILE_SOURCE)
	@printf 'lockfree-facade-forced-compile-target=host status=pass\n'

test-forced-compile: compile-facade-host
	@printf 'lockfree-forced-compile-status=pass\n'

build-debug:
	@mkdir -p $(DEBUG_BUILD_DIR)
	$(FPC) $(DEBUG_FPC_FLAGS) -FU$(DEBUG_BUILD_DIR) -FE$(DEBUG_BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src $(SOURCE)

run-debug: build-debug
	$(DEBUG_BUILD_DIR)/$(PROGRAM)

test-debug: run-debug

clean:
	rm -rf $(CLEAN_BUILD_DIRS)
