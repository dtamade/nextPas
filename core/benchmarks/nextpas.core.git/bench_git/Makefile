include ../../bench_common.mk

GO ?= go
CARGO ?= cargo
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.git/bench_git
GO_COMPARE_BIN := $(BUILD_DIR)/compare_go/bench_git_go
RUST_COMPARE_BIN := $(BUILD_DIR)/compare_rust/bench_git_rs

.PHONY: compare build-go-compare run-go-compare build-rust-compare run-rust-compare bench-compare

build-go-compare:
	@mkdir -p $(dir $(GO_COMPARE_BIN))
	$(GO) build -o $(GO_COMPARE_BIN) compare_go/main.go

run-go-compare: build-go-compare
	$(GO_COMPARE_BIN)

build-rust-compare:
	@mkdir -p $(dir $(RUST_COMPARE_BIN))
	$(CARGO) build --manifest-path compare_rust/Cargo.toml --release
	@cp compare_rust/target/release/bench_git_rs $(RUST_COMPARE_BIN) 2>/dev/null || cp target/release/bench_git_rs $(RUST_COMPARE_BIN) 2>/dev/null || true

run-rust-compare: build-rust-compare
	$(RUST_COMPARE_BIN)

compare: run run-go-compare run-rust-compare

bench-compare: compare
	@echo "[bench-git] Pascal ns/op vs Go/Rust A/B — see build/bench-git.json + go/rust outputs (xlang normalized)"
