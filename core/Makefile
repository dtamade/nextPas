# nextpas.core Makefile
# FPC 3.3.1+ required

FPC := fpc
FPC_FLAGS := -MObjFPC -Sh -O2 -gl

# Directories
SRC_DIR := src
BUILD_DIR := build
LIB_DIR := $(BUILD_DIR)/lib
BIN_DIR := $(BUILD_DIR)/bin
TESTS_DIR := tests
EXAMPLES_DIR := examples

# FPC unit/output paths
FPC_FLAGS += -FU$(LIB_DIR) -FE$(BIN_DIR) -Fu$(SRC_DIR) -Fi$(SRC_DIR)

.PHONY: build test examples clean dirs

# Default target
build: dirs
	@echo "nextpas.core: nothing to compile yet (library units are compiled on demand)"

# Create build directories
dirs:
	@mkdir -p $(LIB_DIR) $(BIN_DIR)

# Compile and run all tests
test: dirs
	@find $(TESTS_DIR) -name '*.lpr' | while read lpr; do \
		echo "Compiling: $$lpr"; \
		$(FPC) $(FPC_FLAGS) "$$lpr" || exit 1; \
		bin=$$(basename "$$lpr" .lpr); \
		echo "Running: $$bin"; \
		$(BIN_DIR)/$$bin || exit 1; \
		echo ""; \
	done
	@echo "All tests passed."

# Compile all examples
examples: dirs
	@find $(EXAMPLES_DIR) -name '*.lpr' | while read lpr; do \
		echo "Compiling: $$lpr"; \
		$(FPC) $(FPC_FLAGS) "$$lpr" || exit 1; \
	done
	@echo "All examples compiled."

# Clean build artifacts
clean:
	@rm -rf $(BUILD_DIR)
	@echo "Clean."
