ROOT_DIR := $(abspath ../../..)
PROCESS_RUNTIME_CONTRACT_SEED_BUILD_DIR := $(ROOT_DIR)/build/.tmp/core-system-process-runtime-contract-seed
PROCESS_RUNTIME_CONTRACT_SEED_BINARY := $(PROCESS_RUNTIME_CONTRACT_SEED_BUILD_DIR)/test_semantic_runtime_contract_seed
PROCESS_RUNTIME_CONTRACT_SEED_SOURCE := $(ROOT_DIR)/tests/semantic/test_semantic_runtime_contract_seed.pas
PROCESS_RUNTIME_CONTRACT_SEED_FPC_FLAGS := -Fu$(ROOT_DIR)/compiler/frontend -Fu$(ROOT_DIR)/compiler/diagnostics -Fu$(ROOT_DIR)/compiler/syntax -Fu$(ROOT_DIR)/compiler/sema -Fu$(ROOT_DIR)/compiler/ir -Fu$(ROOT_DIR)/rtl/core/base -Fu$(ROOT_DIR)/rtl/core/text
.PHONY: test test-source-contracts test-facade test-contracts test-typinfo-minimal test-sysutils-minimal test-process-runtime-contract-seed clean

test: test-source-contracts test-facade test-contracts test-typinfo-minimal test-sysutils-minimal test-process-runtime-contract-seed

test-source-contracts:
	$(MAKE) -C test_system_source_contracts test

test-facade:
	$(MAKE) -C test_system_facade clean test

test-contracts:
	$(MAKE) -C test_system_contracts clean test

test-typinfo-minimal:
	$(MAKE) -C test_system_typinfo_minimal clean test

test-sysutils-minimal:
	$(MAKE) -C test_system_sysutils_minimal clean test

test-process-runtime-contract-seed:
	rm -rf "$(PROCESS_RUNTIME_CONTRACT_SEED_BUILD_DIR)"
	mkdir -p "$(PROCESS_RUNTIME_CONTRACT_SEED_BUILD_DIR)"
	fpc $(PROCESS_RUNTIME_CONTRACT_SEED_FPC_FLAGS) -FE"$(PROCESS_RUNTIME_CONTRACT_SEED_BUILD_DIR)" -FU"$(PROCESS_RUNTIME_CONTRACT_SEED_BUILD_DIR)" "$(PROCESS_RUNTIME_CONTRACT_SEED_SOURCE)"
	"$(PROCESS_RUNTIME_CONTRACT_SEED_BINARY)"

clean:
	$(MAKE) -C test_system_facade clean
	$(MAKE) -C test_system_contracts clean
	$(MAKE) -C test_system_typinfo_minimal clean
	$(MAKE) -C test_system_sysutils_minimal clean
	rm -rf "$(PROCESS_RUNTIME_CONTRACT_SEED_BUILD_DIR)"
