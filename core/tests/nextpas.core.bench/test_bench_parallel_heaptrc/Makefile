PROGRAM = test_bench_parallel_heaptrc
FPC = fpc
FPCFLAGS = -gh -gl -MObjFPC -Sh -O2
CORE_ROOT = ../../..
SRC_DIR = $(CORE_ROOT)/src

BUILD_DIR = build
BIN_DIR = $(BUILD_DIR)/bin
OBJ_DIR = $(BUILD_DIR)/obj

TARGET = $(BIN_DIR)/$(PROGRAM)

.PHONY: all clean test

all: $(TARGET)

$(TARGET): $(PROGRAM).lpr | $(BIN_DIR) $(OBJ_DIR)
	$(FPC) $(FPCFLAGS) \
		-FU$(OBJ_DIR) -FE$(BIN_DIR) \
		-Fu$(SRC_DIR) -Fi$(SRC_DIR) \
		$(PROGRAM).lpr

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

clean:
	rm -rf $(BUILD_DIR)

test: $(TARGET)
	@output="$$($(TARGET) 2>&1)"; \
	status=$$?; \
	printf '%s\n' "$$output"; \
	test $$status -eq 0; \
	printf '%s\n' "$$output" | grep -q 'PARALLEL_OK'; \
	printf '%s\n' "$$output" | grep -q '0 unfreed memory blocks : 0'
