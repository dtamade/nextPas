FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.ssh/e2e_ssh_live
PROGRAM := test_ssh_e2e
SOURCE := $(PROGRAM).lpr
# 与 common.mk 同级的编译面（含 heaptrc），泄漏门禁由 run_e2e.sh 执行
FPC_FLAGS ?= -MObjFPC -Sh -Sg -O2 -gl -gh -dHEAPTRC_ACTIVE
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: test

# opt-in 门控：默认 SKIP；NEXTPAS_SSH_E2E_LOCAL=1（Docker 夹具）或
# NEXTPAS_SSH_E2E_REMOTE=1（真实服务器，需 HOST/USER/KEYFILE）时执行
test:
	@bash ./run_e2e.sh

clean:
	rm -rf $(BUILD_DIR)
