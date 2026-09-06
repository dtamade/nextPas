FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.respack/bench_writer_memory
PROGRAM := bench_writer_memory
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean compare

build:
	mkdir -p $(BUILD_DIR)
	# Drop cached .ppu: stale caches across source/flag drift crash trunk (EListError); rebuilds recompile anyway.
	rm -f $(BUILD_DIR)/*.ppu
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM) $(SIZE_MB)

test: run

# 直接对比门：同机跑双边各 N 轮，中位数对比 + 校验和一致才算过
# （用法：make compare [ROUNDS=5] [BAND_PCT=10] [PIN_CORES=42-43]）
compare: build
	../compare_bulk_wall.sh $(ROUNDS) $(BAND_PCT)

clean:
	rm -rf $(BUILD_DIR)
