# bench_arena_vs_rtl Makefile

FPC := fpc
FPC_FLAGS := -MObjFPC -Sh -O2 -FU../../../build/projects/nextpas.core.mem/bench_arena_vs_rtl -FE../../../build/projects/nextpas.core.mem/bench_arena_vs_rtl -Fu../../../src -Fi../../../src

.PHONY: build run clean

build: bench_arena_vs_rtl

bench_arena_vs_rtl: bench_arena_vs_rtl.lpr
	$(FPC) $(FPC_FLAGS) bench_arena_vs_rtl.lpr

run: build
	../../../build/projects/nextpas.core.mem/bench_arena_vs_rtl/bench_arena_vs_rtl

clean:
	rm -rf ../../../build/projects/nextpas.core.mem/bench_arena_vs_rtl
