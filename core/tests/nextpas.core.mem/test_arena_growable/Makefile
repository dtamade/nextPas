# test_arena_growable Makefile

FPC := fpc
FPC_FLAGS := -MObjFPC -Sh -O2 -gl -gh -FU../../../build/projects/nextpas.core.mem/test_arena_growable -FE../../../build/projects/nextpas.core.mem/test_arena_growable -Fu../../../src -Fi../../../src

.PHONY: build test clean

build: test_arena_growable

test_arena_growable: test_arena_growable.lpr
	$(FPC) $(FPC_FLAGS) test_arena_growable.lpr

test: build
	../../../build/projects/nextpas.core.mem/test_arena_growable/test_arena_growable

clean:
	rm -rf ../../../build/projects/nextpas.core.mem/test_arena_growable
