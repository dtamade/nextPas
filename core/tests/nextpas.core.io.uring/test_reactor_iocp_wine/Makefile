FPC ?= fpc
WINE ?= wine
UNAME_S := $(shell uname -s 2>/dev/null || echo unknown)
WINDOWS_HOST := $(filter Windows_NT MINGW% MSYS% CYGWIN%,$(OS) $(UNAME_S))
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.io.uring/test_reactor_iocp_wine
WINE_BUILD_DIR ?= $(BUILD_DIR)_wine_win64
PROGRAM := test_reactor_iocp_wine
SOURCE := $(PROGRAM).lpr
BASE_FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS ?= $(BASE_FPC_FLAGS)
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
WINE_FPC_FLAGS ?= $(BASE_FPC_FLAGS) -Twin64 -Px86_64
WINE_FPC_FLAGS += -FU$(WINE_BUILD_DIR) -FE$(WINE_BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test wine-build wine-runtime-smoke focused-runtime clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test:
	@if [ -n "$(WINDOWS_HOST)" ]; then \
		$(MAKE) run; \
	elif command -v $(WINE) >/dev/null 2>&1; then \
		$(MAKE) wine-runtime-smoke; \
	else \
		echo "SKIP: IOCP gate requires Wine (Windows-only module)"; \
		exit 0; \
	fi

wine-build:
	@mkdir -p $(WINE_BUILD_DIR)
	$(FPC) $(WINE_FPC_FLAGS) $(SOURCE)

wine-runtime-smoke: wine-build
	@command -v $(WINE) >/dev/null 2>&1 || { echo "wine-runtime-smoke requires Wine; this is not real Windows runtime evidence"; exit 2; }
	@echo "truth=wine-runtime-smoke; not real Windows runtime ready"
	$(WINE) $(WINE_BUILD_DIR)/$(PROGRAM).exe

focused-runtime: wine-runtime-smoke

clean:
	rm -rf $(BUILD_DIR) $(WINE_BUILD_DIR)
