FPC ?= fpc
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.id/test_xid_counter_wrap_contract
PROGRAMS := test_xid_counter_wrap_contract test_xid_counter_wrap_max_contract
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu. -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	@for program in $(PROGRAMS); do \
		$(FPC) $(FPC_FLAGS) "$$program.lpr"; \
	done

run: build
	@for program in $(PROGRAMS); do \
		output="$(BUILD_DIR)/$${program}_output.txt"; \
		timeout 5s "$(BUILD_DIR)/$$program" 2>&1 | tee "$$output"; \
		grep -Eq '^[[:space:]]*0[[:space:]]+unfreed[[:space:]]+memory[[:space:]]+blocks([[:space:]:]|$$)' "$$output" || (echo "LEAK DETECTED"; exit 1); \
	done

test: run

clean:
	rm -rf $(BUILD_DIR)
