# Cross-lang TUI microbench (nextPas / Go / Rust)
# Same methodology simplified kernels — NOT full ratatui/crossterm.

FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/benchmarks/nextpas.core.tui/bench_go_rust
PROGRAM := bench_go_rust
SOURCE := $(PROGRAM).lpr

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
	$(GO) run bench_tui_go.go

rust:
	@mkdir -p $(BUILD_DIR)
	$(RUSTC) -O -C opt-level=3 bench_tui_rust.rs -o $(BUILD_DIR)/bench_tui_rust
	$(BUILD_DIR)/bench_tui_rust

compare: run go rust
	@echo
	@echo 'compare notes:'
	@echo '  Same ops: DiffIdentical / DiffDirty10 @ 200x50; ParseAscii / ParseCsiUp'
	@echo '  Simplified kernels only — not full ratatui/crossterm/tcell.'
	@echo '  Authoritative nextPas gate: core/tests/nextpas.core.tui/scorecard'

clean:
	rm -rf $(BUILD_DIR)
