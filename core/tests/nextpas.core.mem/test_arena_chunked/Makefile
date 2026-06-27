PROJECT = test_arena_chunked

FPC ?= fpc
CORE_ROOT = ../../..
BUILD_DIR = $(CORE_ROOT)/build/projects/nextpas.core.mem/$(PROJECT)

FPC_FLAGS = -MObjFPC -Sh -O2 -gl -gh \
  -Fu$(CORE_ROOT)/src \
  -Fi$(CORE_ROOT)/src \
  -FE$(BUILD_DIR) \
  -FU$(BUILD_DIR)

.PHONY: all clean test

all: $(PROJECT)

$(PROJECT): $(PROJECT).lpr
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(PROJECT).lpr

clean:
	rm -rf $(BUILD_DIR)

test: $(PROJECT)
	$(BUILD_DIR)/$(PROJECT)
