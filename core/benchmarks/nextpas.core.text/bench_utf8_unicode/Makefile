FPC ?= fpc
GO ?= go
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.text/bench_utf8_unicode
PROGRAM := bench_utf8_unicode
SOURCE := $(PROGRAM).lpr
GO_COMPARE_DIR := $(BUILD_DIR)/compare_go
GO_COMPARE_BIN := $(GO_COMPARE_DIR)/bench_utf8_unicode_go
FPC_FLAGS ?= -MObjFPC -Sh -O3 -Xs
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

.PHONY: build run build-go-compare run-go-compare compare test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

build-go-compare:
	@mkdir -p $(GO_COMPARE_DIR)
	cd compare_go && $(GO) build -o $(abspath $(GO_COMPARE_BIN)) .

run-go-compare: build-go-compare
	$(GO_COMPARE_BIN)

compare: run run-go-compare

test: run

clean:
	rm -rf $(BUILD_DIR)
