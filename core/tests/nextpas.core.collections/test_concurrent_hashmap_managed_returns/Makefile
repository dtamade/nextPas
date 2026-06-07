FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.collections/test_concurrent_hashmap_managed_returns
PROGRAM := test_concurrent_hashmap_managed_returns
SOURCE := $(PROGRAM).lpr
COMPILE_LOG := $(BUILD_DIR)/compile.log
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	@$(FPC) $(FPC_FLAGS) $(SOURCE) > $(COMPILE_LOG) 2>&1; \
	status=$$?; \
	cat $(COMPILE_LOG); \
	if [ $$status -ne 0 ]; then exit $$status; fi; \
	if grep -E 'nextpas\.core\.collections\.concurrent\.hashmap\.pas\([0-9]+,[0-9]+\) Warning: Function result variable of a managed type does not seem to be initialized' $(COMPILE_LOG); then \
		echo 'ERROR: ConcurrentHashMap managed array-return functions must initialize Result before SetLength.'; \
		exit 1; \
	fi

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

clean:
	rm -rf $(BUILD_DIR)
