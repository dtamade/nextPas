FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.test/nested_softfail_demo
PROGRAM := nested_softfail_demo
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

# Nested SoftFail demo expects exit 1 and layered messages.
run: build
	@set +e; \
	OUT=$$($(BUILD_DIR)/$(PROGRAM) 2>&1); \
	EC=$$?; \
	printf '%s\n' "$$OUT"; \
	echo "$$OUT" | grep -q 'leaf-message=leaf-soft' || { echo 'missing leaf-soft'; exit 1; }; \
	echo "$$OUT" | grep -q 'parent-soft' || { echo 'missing parent-soft'; exit 1; }; \
	echo "$$OUT" | grep -q 'nested_softfail_demo-status=fail-as-expected' || exit 1; \
	[ $$EC -eq 1 ] || { echo "expected exit 1, got $$EC"; exit 1; }; \
	echo 'nested_softfail_demo: OK'

clean:
	rm -rf $(BUILD_DIR)
