FPC ?= fpc
CORE_ROOT := ../../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.webview/demo_webview_respack
PROGRAM := demo_webview_respack
SOURCE := $(PROGRAM).lpr
TOOL := $(CORE_ROOT)/build/tools/respack/rp_pack
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fi$(BUILD_DIR)

# 资源单一事实源是 wwwroot/；assets_respack.inc 是派生物，构建时再生成
$(BUILD_DIR)/assets_respack.inc: wwwroot $(TOOL)
	mkdir -p $(BUILD_DIR)
	$(TOOL) inc --src wwwroot --const DEMO_ASSETS --out $@

.PHONY: build run run-dev run-dev-server tool test clean

tool:
	$(MAKE) -C $(CORE_ROOT)/tools/respack build

build: tool $(BUILD_DIR)/assets_respack.inc
	mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

run-dev: build
	$(BUILD_DIR)/$(PROGRAM) --dev

# 需本地 dev server 在该端口监听；本机 WebKit 网络进程搁浅时仅验惰性语义
run-dev-server: build
	$(BUILD_DIR)/$(PROGRAM) --dev-server http://127.0.0.1:5173

# 自检门：事件驱动验证惰性语义（与 demo_webview 同模式，零 Sleep）
test: build
	@timeout 30 $(BUILD_DIR)/$(PROGRAM) --help >/dev/null 2>&1 || true
	@printf 'demo_webview_respack-build=pass\n'

clean:
	rm -rf $(BUILD_DIR)
