PROGRAM := rp_pack
CORE_ROOT := ../..
BUILD_DIR := $(CORE_ROOT)/build/tools/respack

FPC ?= fpc
FLAGS := -MObjFPC -Sh -O2 -FE$(BUILD_DIR) -FU$(BUILD_DIR) \
         -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

build:
	mkdir -p $(BUILD_DIR)
	$(FPC) rp_pack.lpr $(FLAGS)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: build clean
