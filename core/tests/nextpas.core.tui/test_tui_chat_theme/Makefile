FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.tui/test_tui_chat_theme
PROGRAM := test_tui_chat_theme
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O1 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
.PHONY: build run test clean
build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)
run: build
	$(BUILD_DIR)/$(PROGRAM)
test: run
clean:
	rm -rf $(BUILD_DIR)
