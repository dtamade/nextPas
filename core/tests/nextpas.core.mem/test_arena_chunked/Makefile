# test_arena_chunked Makefile

FPC := fpc
FPC_FLAGS := -MObjFPC -Sh -O2 -gl -gh -FU../../../build/projects/nextpas.core.mem/test_arena_chunked -FE../../../build/projects/nextpas.core.mem/test_arena_chunked -Fu../../../src -Fi../../../src

.PHONY: build test clean

build: test_arena_chunked

test_arena_chunked: test_arena_chunked.lpr
	@mkdir -p ../../../build/projects/nextpas.core.mem/test_arena_chunked
	$(FPC) $(FPC_FLAGS) test_arena_chunked.lpr

test: build
	../../../build/projects/nextpas.core.mem/test_arena_chunked/test_arena_chunked

clean:
	rm -rf ../../../build/projects/nextpas.core.mem/test_arena_chunked
