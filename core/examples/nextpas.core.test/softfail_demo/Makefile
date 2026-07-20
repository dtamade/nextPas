FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.test/softfail_demo
PROGRAM := softfail_demo
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

# SoftFail demo is *expected* to exit 1 with joined messages.
run: build
	@set +e; \
	OUT=$$($(BUILD_DIR)/$(PROGRAM) 2>&1); \
	EC=$$?; \
	printf '%s\n' "$$OUT"; \
	echo "$$OUT" | grep -q 'alpha; beta; gamma' || { echo 'softfail_demo: missing join message'; exit 1; }; \
	echo "$$OUT" | grep -q 'softfail_demo-status=fail-as-expected' || { echo 'softfail_demo: missing status'; exit 1; }; \
	[ $$EC -eq 1 ] || { echo "softfail_demo: expected exit 1, got $$EC"; exit 1; }; \
	echo 'softfail_demo: OK (exit 1 + join message)'

clean:
	rm -rf $(BUILD_DIR)
