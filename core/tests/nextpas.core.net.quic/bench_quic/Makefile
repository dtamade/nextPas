PROGRAM := bench_quic

FPC ?= fpc

CORE_ROOT   := ../../..
MODULE_NAME := $(notdir $(abspath $(CURDIR)/..))
TEST_NAME   := $(notdir $(abspath $(CURDIR)))

SOURCE  ?= $(PROGRAM).lpr

BUILD_DIR ?= $(CORE_ROOT)/build/projects/$(MODULE_NAME)/$(TEST_NAME)

# Benchmark build: -O2 without heap trace (heaptrc distorts timing)
FPC_FLAGS = -MObjFPC -Sh -O2 -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean clean-src

clean-src:
	@find $(CORE_ROOT)/src -maxdepth 1 -type f \( -name "*.ppu" -o -name "*.o" \) -delete 2>/dev/null || true

build: clean-src
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

clean: clean-src
	rm -rf $(BUILD_DIR)
