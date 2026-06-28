# bench/arena/Makefile — 综合跨语言竞技场
#
# make all       — 构建所有语言
# make run       — 运行所有基准
# make go        — Go benchmark
# make rust      — Rust benchmark
# make pascal    — Pascal benchmark (via FPC)
# make clean     — 清理

SHELL := /bin/bash

# Pascal
PASCAL_SRC := bench_arena.pas
PASCAL_BIN := bench_arena_pas
FPC_FLAGS  := -O3 -CX -Xs -Fi../../core/src -Fu../../core/src -Fu../../units/linux-x86_64 -Fi../../units/linux-x86_64

# Go
GO_SRC     := bench_arena.go
GO_BIN     := bench_arena_go

# Rust
RUST_SRC   := bench_arena.rs
RUST_BIN   := bench_arena_rs
RUST_CARGO := Cargo.toml

# 结果目录
RESULTS_DIR := results

.PHONY: all run pascal go rust clean

all: pascal go rust

# === Pascal ===
pascal: $(PASCAL_BIN)
$(PASCAL_BIN): $(PASCAL_SRC)
	fpc $(FPC_FLAGS) -o$@ $<

# === Go ===
go: $(GO_BIN)
$(GO_BIN): $(GO_SRC)
	go build -o $@ $<

# === Rust ===
rust: $(RUST_BIN)
# 需要 Cargo.toml 配合 serde/serde_json/criterion
# 单文件编译：
$(RUST_BIN): $(RUST_SRC)
	@echo "Rust benchmarks use cargo bench — run 'make rust-cargo' instead"
	@touch $@

rust-cargo:
	cargo bench

# === 运行 ===
run: all
	@mkdir -p $(RESULTS_DIR)
	@echo "=== nextPas Arena Benchmark ==="
	@echo ""
	@echo "--- Pascal ---"
	./$(PASCAL_BIN) 2>&1 | tee $(RESULTS_DIR)/pascal.txt
	@echo ""
	@echo "--- Go ---"
	@echo "Run: go test -bench=. -benchmem -count=6 | tee results/go.txt"

clean:
	rm -f $(PASCAL_BIN) $(GO_BIN) $(RUST_BIN) *.o *.ppu
	rm -rf $(RESULTS_DIR)
