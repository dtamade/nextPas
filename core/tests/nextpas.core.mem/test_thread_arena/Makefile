PROJECT = test_thread_arena
EXEC = $(PROJECT)
SRC = $(PROJECT).lpr

FPC = fpc
UNIT_DIR = ../../../src
BUILD_DIR = ../../../build/projects/nextpas.core.mem/$(PROJECT)
OUTPUT_DIR = $(BUILD_DIR)
PPU_DIR = $(BUILD_DIR)/units

FPC_FLAGS = -MObjFPC -Sh -gl -gh \
  -Fu$(UNIT_DIR) \
  -FE$(OUTPUT_DIR) \
  -FU$(PPU_DIR) \
  -Fi$(UNIT_DIR) \
  -Fl/usr/lib/x86_64-linux-gnu

.PHONY: all clean test

all: $(EXEC)

$(EXEC): $(SRC)
	@mkdir -p $(OUTPUT_DIR) $(PPU_DIR)
	$(FPC) $(FPC_FLAGS) $(SRC)

clean:
	rm -rf $(BUILD_DIR)

test: $(EXEC)
	$(OUTPUT_DIR)/$(EXEC)
