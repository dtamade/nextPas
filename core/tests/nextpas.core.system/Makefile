.PHONY: test test-source-contracts test-facade test-typinfo-minimal test-sysutils-minimal test-process-runtime-contract-seed test-object-free-runtime-contract test-field-dynarray-contract test-field-dynarray-runtime-smoke test-large-alloc-runtime-smoke test-stage0-system-object-free-query clean

ROOT_DIR := $(abspath ../../..)
TARGET_ID := linux-x86_64
PROCESS_RUNTIME_CONTRACT_SEED_BUILD_DIR := $(ROOT_DIR)/build/.tmp/core-system-process-runtime-contract-seed
PROCESS_RUNTIME_CONTRACT_SEED_BINARY := $(PROCESS_RUNTIME_CONTRACT_SEED_BUILD_DIR)/test_semantic_runtime_contract_seed
PROCESS_RUNTIME_CONTRACT_SEED_SOURCE := $(ROOT_DIR)/tests/semantic/test_semantic_runtime_contract_seed.pas
PROCESS_RUNTIME_CONTRACT_SEED_FPC_FLAGS := -Fu$(ROOT_DIR)/compiler/frontend -Fu$(ROOT_DIR)/compiler/diagnostics -Fu$(ROOT_DIR)/compiler/syntax -Fu$(ROOT_DIR)/compiler/sema -Fu$(ROOT_DIR)/compiler/ir -Fu$(ROOT_DIR)/rtl/core/base -Fu$(ROOT_DIR)/rtl/core/text
OBJECT_FREE_RUNTIME_CONTRACT_BUILD_DIR := $(ROOT_DIR)/build/.tmp/core-system-object-free-runtime-contract
OBJECT_FREE_RUNTIME_CONTRACT_BINARY := $(OBJECT_FREE_RUNTIME_CONTRACT_BUILD_DIR)/test_hir_object_free_contract
OBJECT_FREE_RUNTIME_CONTRACT_SOURCE := $(ROOT_DIR)/tests/hir/test_hir_object_free_contract.pas
OBJECT_FREE_RUNTIME_CONTRACT_FPC_FLAGS := -Fu$(ROOT_DIR)/compiler/sema -Fu$(ROOT_DIR)/compiler/syntax -Fu$(ROOT_DIR)/compiler/ir -Fu$(ROOT_DIR)/rtl/core/base -Fu$(ROOT_DIR)/rtl/core/text
FIELD_DYNARRAY_CONTRACT_BUILD_DIR := $(ROOT_DIR)/build/.tmp/core-system-field-dynarray-contract
FIELD_DYNARRAY_CONTRACT_BINARY := $(FIELD_DYNARRAY_CONTRACT_BUILD_DIR)/test_hir_field_dynarray_contract
FIELD_DYNARRAY_CONTRACT_SOURCE := $(ROOT_DIR)/tests/hir/test_hir_field_dynarray_contract.pas
FIELD_DYNARRAY_CONTRACT_FPC_FLAGS := -Fu$(ROOT_DIR)/compiler/frontend -Fu$(ROOT_DIR)/compiler/diagnostics -Fu$(ROOT_DIR)/compiler/syntax -Fu$(ROOT_DIR)/compiler/sema -Fu$(ROOT_DIR)/compiler/ir -Fu$(ROOT_DIR)/rtl/core/base -Fu$(ROOT_DIR)/rtl/core/text
FIELD_DYNARRAY_RUNTIME_BUILD_DIR := $(ROOT_DIR)/build/.tmp/core-system-field-dynarray-runtime-smoke
FIELD_DYNARRAY_RUNTIME_BINARY := $(FIELD_DYNARRAY_RUNTIME_BUILD_DIR)/test_hir_field_dynarray_release_runtime_smoke
FIELD_DYNARRAY_RUNTIME_SOURCE := $(ROOT_DIR)/tests/hir/test_hir_field_dynarray_release_runtime_smoke.pas
FIELD_DYNARRAY_RUNTIME_FPC_FLAGS := -Fu$(ROOT_DIR)/compiler/frontend -Fu$(ROOT_DIR)/compiler/diagnostics -Fu$(ROOT_DIR)/compiler/syntax -Fu$(ROOT_DIR)/compiler/sema -Fu$(ROOT_DIR)/compiler/ir -Fu$(ROOT_DIR)/rtl/core/base -Fu$(ROOT_DIR)/rtl/core/text
LARGE_ALLOC_RUNTIME_BUILD_DIR := $(ROOT_DIR)/build/.tmp/core-system-large-alloc-runtime-smoke
LARGE_ALLOC_RUNTIME_BINARY := $(LARGE_ALLOC_RUNTIME_BUILD_DIR)/test_hir_large_alloc_runtime_smoke
LARGE_ALLOC_RUNTIME_SOURCE := $(ROOT_DIR)/tests/hir/test_hir_large_alloc_runtime_smoke.pas
LARGE_ALLOC_RUNTIME_FPC_FLAGS := -Fu$(ROOT_DIR)/compiler/frontend -Fu$(ROOT_DIR)/compiler/diagnostics -Fu$(ROOT_DIR)/compiler/syntax -Fu$(ROOT_DIR)/compiler/sema -Fu$(ROOT_DIR)/compiler/ir -Fu$(ROOT_DIR)/rtl/core/base -Fu$(ROOT_DIR)/rtl/core/text
STAGE0_SYSTEM_OBJECT_FREE_QUERY_BUILD_DIR := $(ROOT_DIR)/build/.tmp/core-system-stage0-system-object-free-query
STAGE0_SYSTEM_OBJECT_FREE_QUERY_BINARY := $(STAGE0_SYSTEM_OBJECT_FREE_QUERY_BUILD_DIR)/nextpas
STAGE0_SYSTEM_OBJECT_FREE_QUERY_OUTPUT := $(STAGE0_SYSTEM_OBJECT_FREE_QUERY_BUILD_DIR)/system_object_free_query.out
STAGE0_SYSTEM_OBJECT_FREE_IMPLICIT_QUERY_OUTPUT := $(STAGE0_SYSTEM_OBJECT_FREE_QUERY_BUILD_DIR)/system_object_free_implicit_query.out
STAGE0_SYSTEM_OBJECT_FREE_QUERY_SOURCE := tests/fixtures/system_object_free/system_object_free_binding.pas
STAGE0_SYSTEM_OBJECT_FREE_IMPLICIT_QUERY_SOURCE := tests/fixtures/system_object_free/system_object_free_implicit_binding.pas
STAGE0_SYSTEM_OBJECT_FREE_QUERY_PASS_MARKER := stage0-query-system-object-free-check=pass
STAGE0_SYSTEM_OBJECT_FREE_IMPLICIT_QUERY_PASS_MARKER := stage0-query-system-object-free-implicit-check=pass
STAGE0_SYSTEM_OBJECT_FREE_QUERY_FPC_FLAGS := -Fu$(ROOT_DIR)/compiler/frontend -Fu$(ROOT_DIR)/compiler/diagnostics -Fu$(ROOT_DIR)/compiler/targets -Fu$(ROOT_DIR)/compiler/syntax -Fu$(ROOT_DIR)/compiler/sema -Fu$(ROOT_DIR)/compiler/ir -Fu$(ROOT_DIR)/compiler/backend -Fu$(ROOT_DIR)/compiler/toolchain -Fu$(ROOT_DIR)/tools/stage0 -Fu$(ROOT_DIR)/rtl/core/base -Fu$(ROOT_DIR)/rtl/core/text

test: test-source-contracts test-facade test-typinfo-minimal test-sysutils-minimal test-process-runtime-contract-seed test-object-free-runtime-contract test-field-dynarray-contract test-field-dynarray-runtime-smoke test-large-alloc-runtime-smoke test-stage0-system-object-free-query

test-source-contracts:
	$(MAKE) -C test_system_source_contracts test

test-facade:
	$(MAKE) -C test_system_facade clean test

test-typinfo-minimal:
	$(MAKE) -C test_system_typinfo_minimal clean test

test-sysutils-minimal:
	$(MAKE) -C test_system_sysutils_minimal clean test

test-process-runtime-contract-seed:
	rm -rf "$(PROCESS_RUNTIME_CONTRACT_SEED_BUILD_DIR)"
	mkdir -p "$(PROCESS_RUNTIME_CONTRACT_SEED_BUILD_DIR)"
	fpc $(PROCESS_RUNTIME_CONTRACT_SEED_FPC_FLAGS) -FE"$(PROCESS_RUNTIME_CONTRACT_SEED_BUILD_DIR)" -FU"$(PROCESS_RUNTIME_CONTRACT_SEED_BUILD_DIR)" "$(PROCESS_RUNTIME_CONTRACT_SEED_SOURCE)"
	"$(PROCESS_RUNTIME_CONTRACT_SEED_BINARY)"

test-object-free-runtime-contract:
	rm -rf "$(OBJECT_FREE_RUNTIME_CONTRACT_BUILD_DIR)"
	mkdir -p "$(OBJECT_FREE_RUNTIME_CONTRACT_BUILD_DIR)"
	fpc $(OBJECT_FREE_RUNTIME_CONTRACT_FPC_FLAGS) -FE"$(OBJECT_FREE_RUNTIME_CONTRACT_BUILD_DIR)" -FU"$(OBJECT_FREE_RUNTIME_CONTRACT_BUILD_DIR)" "$(OBJECT_FREE_RUNTIME_CONTRACT_SOURCE)"
	"$(OBJECT_FREE_RUNTIME_CONTRACT_BINARY)"

test-field-dynarray-contract:
	rm -rf "$(FIELD_DYNARRAY_CONTRACT_BUILD_DIR)"
	mkdir -p "$(FIELD_DYNARRAY_CONTRACT_BUILD_DIR)"
	fpc $(FIELD_DYNARRAY_CONTRACT_FPC_FLAGS) -FE"$(FIELD_DYNARRAY_CONTRACT_BUILD_DIR)" -FU"$(FIELD_DYNARRAY_CONTRACT_BUILD_DIR)" "$(FIELD_DYNARRAY_CONTRACT_SOURCE)"
	"$(FIELD_DYNARRAY_CONTRACT_BINARY)"

test-field-dynarray-runtime-smoke:
	rm -rf "$(FIELD_DYNARRAY_RUNTIME_BUILD_DIR)"
	mkdir -p "$(FIELD_DYNARRAY_RUNTIME_BUILD_DIR)"
	fpc $(FIELD_DYNARRAY_RUNTIME_FPC_FLAGS) -FE"$(FIELD_DYNARRAY_RUNTIME_BUILD_DIR)" -FU"$(FIELD_DYNARRAY_RUNTIME_BUILD_DIR)" "$(FIELD_DYNARRAY_RUNTIME_SOURCE)"
	"$(FIELD_DYNARRAY_RUNTIME_BINARY)" "$(FIELD_DYNARRAY_RUNTIME_BUILD_DIR)"

test-large-alloc-runtime-smoke:
	rm -rf "$(LARGE_ALLOC_RUNTIME_BUILD_DIR)"
	mkdir -p "$(LARGE_ALLOC_RUNTIME_BUILD_DIR)"
	fpc $(LARGE_ALLOC_RUNTIME_FPC_FLAGS) -FE"$(LARGE_ALLOC_RUNTIME_BUILD_DIR)" -FU"$(LARGE_ALLOC_RUNTIME_BUILD_DIR)" "$(LARGE_ALLOC_RUNTIME_SOURCE)"
	"$(LARGE_ALLOC_RUNTIME_BINARY)" "$(LARGE_ALLOC_RUNTIME_BUILD_DIR)"

test-stage0-system-object-free-query:
	rm -rf "$(STAGE0_SYSTEM_OBJECT_FREE_QUERY_BUILD_DIR)"
	mkdir -p "$(STAGE0_SYSTEM_OBJECT_FREE_QUERY_BUILD_DIR)"
	fpc $(STAGE0_SYSTEM_OBJECT_FREE_QUERY_FPC_FLAGS) -FE"$(STAGE0_SYSTEM_OBJECT_FREE_QUERY_BUILD_DIR)" -FU"$(STAGE0_SYSTEM_OBJECT_FREE_QUERY_BUILD_DIR)" "$(ROOT_DIR)/tools/stage0/nextpas.pas"
	set -eu; \
	require_pattern() { \
	  pattern="$$1"; \
	  output="$$2"; \
	  failure="$$3"; \
	  if ! grep -Eq "$$pattern" "$$output"; then \
	    cat "$$output"; \
	    echo "[FAIL] $$failure" >&2; \
	    exit 1; \
	  fi; \
	}; \
	run_query() { \
	  label="$$1"; \
	  source_rel="$$2"; \
	  output="$$3"; \
	  owner_unit_id="$$4"; \
	  pass_marker="$$5"; \
	  printf '%s-check=running\n' "$$label"; \
	  printf '%s-command=%s query symbols %s --target %s --workspace %s\n' "$$label" "$(STAGE0_SYSTEM_OBJECT_FREE_QUERY_BINARY)" "$$source_rel" "$(TARGET_ID)" "$(ROOT_DIR)"; \
	  if ! (cd "$(ROOT_DIR)" && NEXTPAS_REPO_ROOT="$(ROOT_DIR)" "$(STAGE0_SYSTEM_OBJECT_FREE_QUERY_BINARY)" query symbols "$$source_rel" --target "$(TARGET_ID)" --workspace "$(ROOT_DIR)" >"$$output" 2>&1); then \
	    cat "$$output"; \
	    echo "[FAIL] $$label-failed" >&2; \
	    exit 1; \
	  fi; \
	  cat "$$output"; \
	  object_free_offset="$$(awk 'BEGIN { offset = 0 } { idx = index($$0, "Worker.Free"); if (idx > 0) { print offset + idx + length("Worker.") - 1; exit } offset += length($$0) + 1 }' "$(ROOT_DIR)/$$source_rel")"; \
	  require_pattern '^query-symbols=\[.*"name":"TObject".*"kind":"type".*"ownerUnitId":"system".*"ownerUnitName":"System"' "$$output" "$$label-missing-object-type-symbol"; \
	  require_pattern '^query-symbols=\[.*"name":"TObject.Free".*"kind":"method".*"ownerUnitId":"system".*"ownerUnitName":"System".*"paramCount":0' "$$output" "$$label-missing-object-free-symbol"; \
	  require_pattern "^query-bindings=\\[.*\"kind\":\"member-call\".*\"name\":\"Free\".*\"ownerUnitId\":\"$$owner_unit_id\".*\"byteOffset\":$$object_free_offset.*\"targetSymbolId\":[1-9][0-9]*" "$$output" "$$label-missing-object-free-binding"; \
	  require_pattern "^query-definitions=\\[.*\"bindingKind\":\"member-call\".*\"bindingName\":\"Free\".*\"bindingByteOffset\":$$object_free_offset.*\"targetName\":\"TObject.Free\".*\"targetKind\":\"method\".*\"targetOwnerUnitName\":\"System\".*\"targetSourcePath\":\".*units/linux-x86_64/System\\.pas\"" "$$output" "$$label-missing-object-free-definition"; \
	  require_pattern '^command-envelope=.*"querySymbols":\[.*"name":"TObject.Free".*"kind":"method".*"ownerUnitId":"system".*"ownerUnitName":"System".*"paramCount":0' "$$output" "$$label-missing-object-free-symbol-envelope"; \
	  require_pattern "^command-envelope=.*\"queryDefinitions\":\\[.*\"bindingKind\":\"member-call\".*\"bindingName\":\"Free\".*\"bindingByteOffset\":$$object_free_offset.*\"targetName\":\"TObject.Free\".*\"targetKind\":\"method\".*\"targetOwnerUnitName\":\"System\".*\"targetSourcePath\":\".*units/linux-x86_64/System\\.pas\"" "$$output" "$$label-missing-object-free-definition-envelope"; \
	  require_pattern '^mir-status=deferred$$' "$$output" "$$label-missing-deferred-mir"; \
	  require_pattern '^backend-plan-status=deferred$$' "$$output" "$$label-missing-deferred-backend"; \
	  require_pattern '^toolchain-plan-status=deferred$$' "$$output" "$$label-missing-deferred-toolchain"; \
	  printf '%s\n' "$$pass_marker"; \
	}; \
	run_query stage0-query-system-object-free "$(STAGE0_SYSTEM_OBJECT_FREE_QUERY_SOURCE)" "$(STAGE0_SYSTEM_OBJECT_FREE_QUERY_OUTPUT)" systemobjectfreebinding "$(STAGE0_SYSTEM_OBJECT_FREE_QUERY_PASS_MARKER)"; \
	run_query stage0-query-system-object-free-implicit "$(STAGE0_SYSTEM_OBJECT_FREE_IMPLICIT_QUERY_SOURCE)" "$(STAGE0_SYSTEM_OBJECT_FREE_IMPLICIT_QUERY_OUTPUT)" systemobjectfreeimplicitbinding "$(STAGE0_SYSTEM_OBJECT_FREE_IMPLICIT_QUERY_PASS_MARKER)"

clean:
	$(MAKE) -C test_system_facade clean
	$(MAKE) -C test_system_typinfo_minimal clean
	$(MAKE) -C test_system_sysutils_minimal clean
	rm -rf "$(PROCESS_RUNTIME_CONTRACT_SEED_BUILD_DIR)"
	rm -rf "$(OBJECT_FREE_RUNTIME_CONTRACT_BUILD_DIR)"
	rm -rf "$(FIELD_DYNARRAY_CONTRACT_BUILD_DIR)"
	rm -rf "$(FIELD_DYNARRAY_RUNTIME_BUILD_DIR)"
	rm -rf "$(LARGE_ALLOC_RUNTIME_BUILD_DIR)"
	rm -rf "$(STAGE0_SYSTEM_OBJECT_FREE_QUERY_BUILD_DIR)"
