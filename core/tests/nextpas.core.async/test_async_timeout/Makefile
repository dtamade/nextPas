FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.async/test_async_timeout
PROGRAM := test_async_timeout
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
OUTPUT_FILE := /tmp/test_async_timeout_output.txt

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	@$(BUILD_DIR)/$(PROGRAM) > $(OUTPUT_FILE) 2>&1; \
	program_status=$$?; \
	cat $(OUTPUT_FILE); \
	grep -q "0 unfreed memory blocks" $(OUTPUT_FILE) || { echo "LEAK DETECTED"; exit 1; }; \
	exit $$program_status

test: run

clean:
	rm -rf $(BUILD_DIR)
