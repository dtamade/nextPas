FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.http/bench_server
PROGRAM := bench_http_server
SOURCE := bench_http_server.lpr
EXTRA_FLAGS ?=
FPC_FLAGS := -MObjFPC -Sh -O2 $(EXTRA_FLAGS)
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

.PHONY: build run clean smoke-tls

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

# C-H1: small HTTPS H1 keep-alive smoke (self-signed)
smoke-tls: build
	$(BUILD_DIR)/$(PROGRAM) --backend epoll --tls \
	  --requests 200 --threads 2 --workload no_url

clean:
	rm -rf $(BUILD_DIR)
