FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.http/bench_h1parser
PROGRAM := bench_h1parser
SOURCE := bench_h1parser.lpr
EXTRA_FLAGS ?=
EFFECTIVE_LLHTTP_ROOT := $(if $(LLHTTP_ROOT),$(LLHTTP_ROOT),$(NEXTPAS_LLHTTP_ROOT))
FPC_FLAGS := -MObjFPC -Sh -O2 $(EXTRA_FLAGS)
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

.PHONY: build run run-c clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

run-c:
	$(MAKE) -C compare_c run LLHTTP_ROOT="$(EFFECTIVE_LLHTTP_ROOT)"

clean:
	rm -rf $(BUILD_DIR)
