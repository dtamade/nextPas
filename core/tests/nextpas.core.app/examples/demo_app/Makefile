FPC ?= fpc
CORE_ROOT := ../../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.app/demo_app
PROGRAM := demo_app
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
.PHONY: build run test heaptrc clean
build:
	mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)
run: build
	$(BUILD_DIR)/$(PROGRAM)
test: build
	rm -f $(BUILD_DIR)/run.log $(BUILD_DIR)/heaptrc.log
	@timeout 30 $(BUILD_DIR)/$(PROGRAM) --selftest > $(BUILD_DIR)/run.log 2>&1 || { cat $(BUILD_DIR)/run.log; exit 1; }
	@grep -F 'demo-pass all steps' $(BUILD_DIR)/run.log >/dev/null || { cat $(BUILD_DIR)/run.log; exit 1; }
	@HEAPTRC=log=$(BUILD_DIR)/heaptrc.log timeout 30 $(BUILD_DIR)/$(PROGRAM) --selftest >> $(BUILD_DIR)/run.log 2>&1 || { cat $(BUILD_DIR)/run.log; test ! -f $(BUILD_DIR)/heaptrc.log || cat $(BUILD_DIR)/heaptrc.log; exit 1; }
	@grep -F '0 unfreed memory blocks' $(BUILD_DIR)/heaptrc.log >/dev/null || { cat $(BUILD_DIR)/run.log; cat $(BUILD_DIR)/heaptrc.log; exit 1; }
	@cat $(BUILD_DIR)/run.log
	@printf '\ndemo_app-selftest=pass\n'
heaptrc: test
clean:
	rm -rf $(BUILD_DIR)
