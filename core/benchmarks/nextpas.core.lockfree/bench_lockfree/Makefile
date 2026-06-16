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

.PHONY: build run build-rust-compare run-rust-compare build-go-compare run-go-compare build-cpp-compare run-cpp-compare compare clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

build-rust-compare:
	@mkdir -p $(RUST_COMPARE_DIR)
	$(RUSTC) -C opt-level=3 compare_rust/main.rs -o $(RUST_COMPARE_BIN)

run-rust-compare: build-rust-compare
	$(RUST_COMPARE_BIN)

build-go-compare:
	@mkdir -p $(GO_COMPARE_DIR)
	$(GO) build -o $(GO_COMPARE_BIN) compare_go/main.go

run-go-compare: build-go-compare
	$(GO_COMPARE_BIN)

build-cpp-compare:
	@mkdir -p $(CPP_COMPARE_DIR)
	$(CXX) -std=c++17 -O2 -pthread compare_cpp/main.cpp -o $(CPP_COMPARE_BIN)

run-cpp-compare: build-cpp-compare
	$(CPP_COMPARE_BIN)

compare: run run-rust-compare run-go-compare run-cpp-compare

clean:
	rm -rf $(BUILD_DIR)
