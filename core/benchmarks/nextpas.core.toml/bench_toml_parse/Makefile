FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.toml/bench_toml_parse
PROGRAM := bench_toml_parse
SOURCE := bench_toml_parse.lpr
FPC_FLAGS := -MObjFPC -Sh -O2
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

.PHONY: build run bench clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

bench: run

clean:
	rm -rf $(BUILD_DIR)
