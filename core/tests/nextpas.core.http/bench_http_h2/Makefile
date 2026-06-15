FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.http/bench_http_h2
BUILD_DIR_FAST ?= $(CORE_ROOT)/build/projects/nextpas.core.http/bench_http_h2_fast
BUILD_DIR_FASTEST ?= $(CORE_ROOT)/build/projects/nextpas.core.http/bench_http_h2_fastest
PROGRAM := bench_http_h2
SOURCE := $(PROGRAM).lpr
EXTRA_FLAGS ?=
FPC_FLAGS := -MObjFPC -Sh -O2 $(EXTRA_FLAGS) -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

# Fast builds: no heaptrace, no bounds checks
FPC_FAST := -MObjFPC -Sh -O2 -dNDEBUG
FPC_FAST += -FU$(BUILD_DIR_FAST) -FE$(BUILD_DIR_FAST) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

# Fastest builds: -O3, no heaptrace
FPC_FASTEST := -MObjFPC -Sh -O3 -dNDEBUG
FPC_FASTEST += -FU$(BUILD_DIR_FASTEST) -FE$(BUILD_DIR_FASTEST) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

.PHONY: all build run run-fast run-fastest clean test

all: build

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

run-fast:
	@mkdir -p $(BUILD_DIR_FAST)
	$(FPC) $(FPC_FAST) $(SOURCE)
	$(BUILD_DIR_FAST)/$(PROGRAM)

run-fastest:
	@mkdir -p $(BUILD_DIR_FASTEST)
	$(FPC) $(FPC_FASTEST) $(SOURCE)
	$(BUILD_DIR_FASTEST)/$(PROGRAM)

clean:
	rm -rf $(BUILD_DIR) $(BUILD_DIR_FAST) $(BUILD_DIR_FASTEST)

test: run
