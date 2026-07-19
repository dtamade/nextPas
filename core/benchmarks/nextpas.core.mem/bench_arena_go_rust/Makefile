# Cross-lang + SC1-aligned heap truth (nextPas / Go / Rust)
#
# Default flags match scorecard RELEASE=1 (no -gl/-gh) so heap ns/op is
# comparable to SCORECARD.md publish numbers.

FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/benchmarks/nextpas.core.mem/bench_arena_go_rust
PROGRAM := bench_arena_go_rust
SOURCE := $(PROGRAM).lpr

# RELEASE-like (default)
FPC_FLAGS ?= -MObjFPC -Sh -O2
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

GO ?= go
RUSTC ?= rustc

.PHONY: build run go rust compare clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

go:
	$(GO) run bench_arena_go.go

rust:
	@mkdir -p $(BUILD_DIR)
	$(RUSTC) -O -C opt-level=3 bench_arena_rust.rs -o $(BUILD_DIR)/bench_arena_rust
	$(BUILD_DIR)/bench_arena_rust

# A: arena rows vs Go/Rust bump; B: heap rows = SC1 (do not cross-compare A vs B).
compare: run go rust
	@echo
	@echo 'compare notes:'
	@echo '  A arena  — same batch constants as Go/Rust bump benches (P3)'
	@echo '  B heap   — SC1 flat 200k alloc+free; authoritative Ready = scorecard RELEASE=1'
	@echo '  Do not compare A batch shape to B flat loops or to Go make-without-free.'

clean:
	rm -rf $(BUILD_DIR)
