FPC ?= fpc
RUSTC ?= rustc
GO ?= go
CXX ?= g++
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.lockfree/bench_lockfree
PROGRAM := bench_lockfree
SOURCE := $(PROGRAM).lpr
RUST_COMPARE_DIR := $(BUILD_DIR)/compare_rust
RUST_COMPARE_BIN := $(RUST_COMPARE_DIR)/bench_lockfree_rust
GO_COMPARE_DIR := $(BUILD_DIR)/compare_go
GO_COMPARE_BIN := $(GO_COMPARE_DIR)/bench_lockfree_go
CPP_COMPARE_DIR := $(BUILD_DIR)/compare_cpp
CPP_COMPARE_BIN := $(CPP_COMPARE_DIR)/bench_lockfree_cpp
FPC_FLAGS ?= -MObjFPC -Sh -O2
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

ENVELOPE_SCRIPT := $(CORE_ROOT)/docs/lockfree/scripts/print-bench-envelope.sh
ENVELOPE_EXTRA ?= samples=1 (single run; raise N for claims)

# Keep historical entrypoints substring for test_lockfree source-contract; Q5 adds matched/envelope.
.PHONY: build run build-rust-compare run-rust-compare build-go-compare run-go-compare build-cpp-compare run-cpp-compare compare clean
.PHONY: run-matched compare-matched compare-matched-formal envelope envelope-matched

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

envelope:
	@bash $(ENVELOPE_SCRIPT) "bench_lockfree micro+matched OPS=1e6 CAP=1024" \
		"command=make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree run" \
		"measured=suite-dependent" \
		"stats=$(ENVELOPE_EXTRA)"

envelope-matched:
	@bash $(ENVELOPE_SCRIPT) "Q5 matched C1/C2 OPS=1e6 CAP=1024 channel" \
		"command=make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree compare-matched" \
		"measured=OPS=1000000 wall-clock per scenario" \
		"stats=$(ENVELOPE_EXTRA)"

run: build envelope
	$(BUILD_DIR)/$(PROGRAM) all

run-matched: build envelope-matched
	$(BUILD_DIR)/$(PROGRAM) matched

build-rust-compare:
	@mkdir -p $(RUST_COMPARE_DIR)
	@if command -v $(RUSTC) >/dev/null 2>&1; then \
	  $(RUSTC) -C opt-level=3 compare_rust/main.rs -o $(RUST_COMPARE_BIN); \
	else \
	  echo "rustc missing: skip rust compare"; \
	fi

run-rust-compare: build-rust-compare
	@if [ -x "$(RUST_COMPARE_BIN)" ]; then $(RUST_COMPARE_BIN); else echo "SKIP: rust compare binary missing"; fi

build-go-compare:
	@mkdir -p $(GO_COMPARE_DIR)
	@if command -v $(GO) >/dev/null 2>&1; then \
	  $(GO) build -o $(GO_COMPARE_BIN) compare_go/main.go; \
	else \
	  echo "go missing: skip go compare"; \
	fi

run-go-compare: build-go-compare
	@if [ -x "$(GO_COMPARE_BIN)" ]; then $(GO_COMPARE_BIN); else echo "SKIP: go compare binary missing"; fi

build-cpp-compare:
	@mkdir -p $(CPP_COMPARE_DIR)
	@if command -v $(CXX) >/dev/null 2>&1; then \
	  $(CXX) -std=c++17 -O2 -pthread compare_cpp/main.cpp -o $(CPP_COMPARE_BIN); \
	else \
	  echo "g++ missing: skip cpp compare"; \
	fi

run-cpp-compare: build-cpp-compare
	@if [ -x "$(CPP_COMPARE_BIN)" ]; then $(CPP_COMPARE_BIN); else echo "SKIP: cpp compare binary missing"; fi

# Full historical compare (includes micro + optional cpp).
compare: run run-rust-compare run-go-compare run-cpp-compare

# Q5 default: matched multi-thread only (nextpas + go + rust).
compare-matched: run-matched
	@echo ""
	@bash $(ENVELOPE_SCRIPT) "Q5 Go C1/C2" \
		"command=make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree run-go-compare" \
		"measured=OPS=1000000" \
		"stats=$(ENVELOPE_EXTRA)"
	@$(MAKE) run-go-compare
	@echo ""
	@bash $(ENVELOPE_SCRIPT) "Q5 Rust C1/C2" \
		"command=make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree run-rust-compare" \
		"measured=OPS=1000000" \
		"stats=$(ENVELOPE_EXTRA)"
	@$(MAKE) run-rust-compare

# Formal: SAMPLES>=3, aggregate mean/median/min/max into bench-results/.
SAMPLES ?= 3
compare-matched-formal:
	@SAMPLES=$(SAMPLES) bash $(CORE_ROOT)/docs/lockfree/scripts/run-q5-matched-formal.sh

clean:
	rm -rf $(BUILD_DIR)
