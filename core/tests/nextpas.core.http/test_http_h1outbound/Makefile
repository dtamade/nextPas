FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.http/test_http_h1outbound
PROGRAM := test_http_h1outbound
SOURCE := test_http_h1outbound.lpr
EXTRA_FLAGS ?=
FPC_FLAGS := -MObjFPC -Sh -O2 $(EXTRA_FLAGS) -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

clean:
	rm -rf $(BUILD_DIR)
