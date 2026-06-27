# bench_arena_vs_rtl Makefile

FPC := fpc
BUILD_DIR := ../../../build/projects/nextpas.core.mem/bench_arena_vs_rtl
FPC_FLAGS := -MObjFPC -Sh -O2 -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu../../../src -Fi../../../src

.PHONY: build run clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) bench_arena_vs_rtl.lpr

run: build
	$(BUILD_DIR)/bench_arena_vs_rtl

clean:
	rm -rf $(BUILD_DIR)
