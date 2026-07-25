FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.http/bench_h2_server
PROGRAM := bench_h2_server
SOURCE := bench_h2_server.lpr
EXTRA_FLAGS ?=
FPC_FLAGS := -MObjFPC -Sh -O2 $(EXTRA_FLAGS)
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

.PHONY: build run clean smoke smoke-tls

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

smoke: build
	$(BUILD_DIR)/$(PROGRAM) --mode multiplex --backend epoll \
	  --connections 4 --streams 4 --batches 25

# C-D: small HTTPS ALPN h2 smoke (self-signed)
smoke-tls: build
	$(BUILD_DIR)/$(PROGRAM) --mode multiplex --backend epoll --tls \
	  --connections 2 --streams 4 --batches 10

clean:
	rm -rf $(BUILD_DIR)
