# Cross-lang mem parity harness (nextPas / Go / Rust)
# Methodology: same BatchCount / SmallSize / reuse loops as sibling sources.

FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/benchmarks/nextpas.core.mem/bench_arena_go_rust
PROGRAM := bench_arena_go_rust
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl
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

# Sequential three-way; human compares rows (same methodology labels).
compare: run go rust
	@echo
	@echo 'compare: nextPas / Go / Rust printed above (same batch/size constants).'
	@echo 'Authoritative mem Ready numbers remain core/tests/.../scorecard RELEASE=1.'

clean:
	rm -rf $(BUILD_DIR)
