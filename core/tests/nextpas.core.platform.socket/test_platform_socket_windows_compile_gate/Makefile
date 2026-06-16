FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.socket/test_platform_socket_windows_compile_gate
PROGRAM := test_platform_socket_windows_compile_gate
SOURCE := $(PROGRAM).lpr
BASE_FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl
FPC_FLAGS ?= $(BASE_FPC_FLAGS) -Twin64 -Px86_64 -Cn
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

clean:
	rm -rf $(BUILD_DIR)
