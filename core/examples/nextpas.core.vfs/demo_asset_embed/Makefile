FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.vfs/demo_asset_embed
PROGRAM := demo_asset_embed
SOURCE := $(PROGRAM).lpr
TOOL := $(CORE_ROOT)/build/tools/respack/rp_pack

FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fi$(BUILD_DIR)

# 资源单一事实源是 wwwroot/；assets_respack.inc 是派生物，构建时再生成。
$(BUILD_DIR)/assets_respack.inc: wwwroot $(TOOL)
	mkdir -p $(BUILD_DIR)
	$(TOOL) inc --src wwwroot --const DEMO_ASSETS --out $@

.PHONY: build run run-dev tool clean

tool:
	$(MAKE) -C $(CORE_ROOT)/tools/respack build

build: tool $(BUILD_DIR)/assets_respack.inc
	mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

run-dev: build
	$(BUILD_DIR)/$(PROGRAM) --dev

clean:
	rm -rf $(BUILD_DIR)
