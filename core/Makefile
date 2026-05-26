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
BENCHMARKS_DIR := benchmarks

# FPC unit/output paths
FPC_FLAGS += -FU$(LIB_DIR) -FE$(BIN_DIR) -Fu$(SRC_DIR) -Fi$(SRC_DIR)

.PHONY: build test examples benchmarks clean dirs

# Default target
build: dirs
	@echo "nextpas.core: nothing to compile yet (library units are compiled on demand)"

# Create build directories
dirs:
	@mkdir -p $(LIB_DIR) $(BIN_DIR)

# Compile and run all tests
test: dirs
	@missing=$$(find $(TESTS_DIR) -name '*.lpr' | while read lpr; do \
		dir=$$(dirname "$$lpr"); \
		if [ ! -f "$$dir/Makefile" ]; then echo "$$dir"; fi; \
	done | sort -u); \
	if [ -n "$$missing" ]; then \
		echo "Missing project Makefile:"; \
		echo "$$missing"; \
		exit 1; \
	fi
	@find $(TESTS_DIR) -mindepth 2 -name Makefile | sort | while read mk; do \
		dir=$$(dirname "$$mk"); \
		echo "Running test project: $$dir"; \
		$(MAKE) -C "$$dir" test || exit 1; \
		echo ""; \
	done
	@echo "All tests passed."

# Compile all examples
examples: dirs
	@missing=$$(find $(EXAMPLES_DIR) -name '*.lpr' | while read lpr; do \
		dir=$$(dirname "$$lpr"); \
		if [ ! -f "$$dir/Makefile" ]; then echo "$$dir"; fi; \
	done | sort -u); \
	if [ -n "$$missing" ]; then \
		echo "Missing project Makefile:"; \
		echo "$$missing"; \
		exit 1; \
	fi
	@find $(EXAMPLES_DIR) -mindepth 2 -name Makefile | sort | while read mk; do \
		dir=$$(dirname "$$mk"); \
		echo "Building example project: $$dir"; \
		$(MAKE) -C "$$dir" build || exit 1; \
		echo ""; \
	done
	@echo "All examples compiled."

# Compile and run all benchmarks
benchmarks: dirs
	@missing=$$(find $(BENCHMARKS_DIR) -name '*.lpr' | while read lpr; do \
		dir=$$(dirname "$$lpr"); \
		if [ ! -f "$$dir/Makefile" ]; then echo "$$dir"; fi; \
	done | sort -u); \
	if [ -n "$$missing" ]; then \
		echo "Missing project Makefile:"; \
		echo "$$missing"; \
		exit 1; \
	fi
	@find $(BENCHMARKS_DIR) -mindepth 2 -name Makefile | sort | while read mk; do \
		dir=$$(dirname "$$mk"); \
		echo "Running benchmark project: $$dir"; \
		$(MAKE) -C "$$dir" run || exit 1; \
		echo ""; \
	done
	@echo "All benchmarks passed."

# Clean build artifacts
clean:
	@rm -rf $(BUILD_DIR)
	@echo "Clean."
