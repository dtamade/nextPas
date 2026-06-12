FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.compress/test_compress_docs_contract
PROGRAM := test_compress_docs_contract
SOURCE := $(PROGRAM).lpr
HEAPTRC_LOG ?= $(BUILD_DIR)/heaptrc.log
RUN_LOG ?= $(BUILD_DIR)/run.log
HEAPTRC_ENV ?= HEAPTRC=log=$(HEAPTRC_LOG)
FPC_FLAGS ?= -MObjFPC -Sh -gh -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

.PHONY: build run test heaptrc clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run heaptrc

heaptrc: build
	@rm -f $(RUN_LOG) $(HEAPTRC_LOG)
	@$(HEAPTRC_ENV) $(BUILD_DIR)/$(PROGRAM) > $(RUN_LOG) 2>&1 || { cat $(RUN_LOG); test ! -f $(HEAPTRC_LOG) || cat $(HEAPTRC_LOG); exit 1; }
	@grep -F '0 unfreed memory blocks' $(HEAPTRC_LOG) >/dev/null || { cat $(RUN_LOG); cat $(HEAPTRC_LOG); exit 1; }
	@cat $(RUN_LOG)
	@cat $(HEAPTRC_LOG)
	@printf '\ncompress-docs-contract-heaptrc=pass\n'

clean:
	rm -rf $(BUILD_DIR)
