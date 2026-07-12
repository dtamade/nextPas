FPC ?= fpc
CORE_ROOT := ../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.text.unicode/bench_unicode
PROGRAM := bench_unicode
SOURCE := $(PROGRAM).lpr
EXTRA_FLAGS ?=
FPC_FLAGS := -MObjFPC -Sh -O2 $(EXTRA_FLAGS)
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run smoke clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

smoke: build
	NEXTPAS_BENCH_MAX_ITERS=20000 $(BUILD_DIR)/$(PROGRAM)

clean:
	rm -rf $(BUILD_DIR)
