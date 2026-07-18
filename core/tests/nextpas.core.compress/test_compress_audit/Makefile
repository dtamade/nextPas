FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.compress/test_compress_audit
NATIVE_BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.compress/test_compress_audit_native
NATIVE_RUNTIME_BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.compress/test_compress_audit_native_runtime
EXAMPLE_NATIVE_BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.compress/compress_roundtrip_native
ZLIB_NATIVE_BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.compress/test_compress_audit_zlib_native
ZLIB_NATIVE_RUNTIME_BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.compress/test_compress_audit_zlib_native_runtime
PROGRAM := test_compress_audit
SOURCE := test_compress_audit.lpr
HEAPTRC_LOG ?= $(BUILD_DIR)/heaptrc.log
RUN_LOG ?= $(BUILD_DIR)/run.log
NATIVE_RUNTIME_HEAPTRC_LOG ?= $(NATIVE_RUNTIME_BUILD_DIR)/heaptrc.log
NATIVE_RUNTIME_RUN_LOG ?= $(NATIVE_RUNTIME_BUILD_DIR)/run.log
ZLIB_NATIVE_RUNTIME_HEAPTRC_LOG ?= $(ZLIB_NATIVE_RUNTIME_BUILD_DIR)/heaptrc.log
ZLIB_NATIVE_RUNTIME_RUN_LOG ?= $(ZLIB_NATIVE_RUNTIME_BUILD_DIR)/run.log
HEAPTRC_ENV ?= HEAPTRC=log=$(HEAPTRC_LOG)
NATIVE_RUNTIME_HEAPTRC_ENV ?= HEAPTRC=log=$(NATIVE_RUNTIME_HEAPTRC_LOG)
ZLIB_NATIVE_RUNTIME_HEAPTRC_ENV ?= HEAPTRC=log=$(ZLIB_NATIVE_RUNTIME_HEAPTRC_LOG)
FPC_FLAGS ?= -MObjFPC -Sh -gh -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib
NATIVE_COMPILE_FLAGS ?= -Cn -dNEXTPAS_USE_LZ4_NATIVE
NATIVE_RUNTIME_FLAGS ?= -dNEXTPAS_USE_LZ4_NATIVE
LZ4_PKG_CONFIG ?= pkg-config
LZ4_LIB_DIR ?= $(shell $(LZ4_PKG_CONFIG) --variable=libdir liblz4 2>/dev/null)
NATIVE_RUNTIME_FPC_FLAGS ?= $(FPC_FLAGS) $(if $(LZ4_LIB_DIR),-Fl$(LZ4_LIB_DIR))
NATIVE_RUNTIME_ENV ?= $(if $(LZ4_LIB_DIR),LD_LIBRARY_PATH=$(LZ4_LIB_DIR)$(if $(LD_LIBRARY_PATH),:$(LD_LIBRARY_PATH),),)
ZLIB_NATIVE_COMPILE_FLAGS ?= -Cn -dNEXTPAS_USE_ZLIB_NATIVE
ZLIB_NATIVE_RUNTIME_FLAGS ?= -dNEXTPAS_USE_ZLIB_NATIVE

.PHONY: build run test audit-gate native-compile native-runtime zlib-native-compile zlib-native-runtime benchmark-compile benchmark-run go-comparator-compile go-comparator-run example-run example-native-compile heaptrc docs-contract-run basic-test-run deep-test-run clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run native-compile zlib-native-compile benchmark-compile go-comparator-compile example-run example-native-compile heaptrc docs-contract-run basic-test-run deep-test-run

audit-gate: test

native-compile:
	@mkdir -p $(NATIVE_BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(NATIVE_COMPILE_FLAGS) -FU$(NATIVE_BUILD_DIR) -FE$(NATIVE_BUILD_DIR) $(SOURCE)
	@printf 'compress-audit-native-lz4-compile=pass\n'

native-runtime:
	@mkdir -p $(NATIVE_RUNTIME_BUILD_DIR)
	$(FPC) $(NATIVE_RUNTIME_FPC_FLAGS) $(NATIVE_RUNTIME_FLAGS) -FU$(NATIVE_RUNTIME_BUILD_DIR) -FE$(NATIVE_RUNTIME_BUILD_DIR) $(SOURCE)
	@rm -f $(NATIVE_RUNTIME_RUN_LOG) $(NATIVE_RUNTIME_HEAPTRC_LOG)
	@$(NATIVE_RUNTIME_ENV) $(NATIVE_RUNTIME_HEAPTRC_ENV) $(NATIVE_RUNTIME_BUILD_DIR)/$(PROGRAM) > $(NATIVE_RUNTIME_RUN_LOG) 2>&1 || { cat $(NATIVE_RUNTIME_RUN_LOG); test ! -f $(NATIVE_RUNTIME_HEAPTRC_LOG) || cat $(NATIVE_RUNTIME_HEAPTRC_LOG); exit 1; }
	@grep -F '0 unfreed memory blocks' $(NATIVE_RUNTIME_HEAPTRC_LOG) >/dev/null || { cat $(NATIVE_RUNTIME_RUN_LOG); cat $(NATIVE_RUNTIME_HEAPTRC_LOG); exit 1; }
	@cat $(NATIVE_RUNTIME_RUN_LOG)
	@cat $(NATIVE_RUNTIME_HEAPTRC_LOG)
	@printf '\ncompress-audit-native-lz4-runtime=pass\n'

zlib-native-compile:
	@mkdir -p $(ZLIB_NATIVE_BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(ZLIB_NATIVE_COMPILE_FLAGS) -FU$(ZLIB_NATIVE_BUILD_DIR) -FE$(ZLIB_NATIVE_BUILD_DIR) $(SOURCE)
	@printf 'compress-audit-native-zlib-compile=pass\n'

zlib-native-runtime:
	@mkdir -p $(ZLIB_NATIVE_RUNTIME_BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(ZLIB_NATIVE_RUNTIME_FLAGS) -FU$(ZLIB_NATIVE_RUNTIME_BUILD_DIR) -FE$(ZLIB_NATIVE_RUNTIME_BUILD_DIR) $(SOURCE)
	@rm -f $(ZLIB_NATIVE_RUNTIME_RUN_LOG) $(ZLIB_NATIVE_RUNTIME_HEAPTRC_LOG)
	@$(ZLIB_NATIVE_RUNTIME_HEAPTRC_ENV) $(ZLIB_NATIVE_RUNTIME_BUILD_DIR)/$(PROGRAM) > $(ZLIB_NATIVE_RUNTIME_RUN_LOG) 2>&1 || { cat $(ZLIB_NATIVE_RUNTIME_RUN_LOG); test ! -f $(ZLIB_NATIVE_RUNTIME_HEAPTRC_LOG) || cat $(ZLIB_NATIVE_RUNTIME_HEAPTRC_LOG); exit 1; }
	@grep -F '0 unfreed memory blocks' $(ZLIB_NATIVE_RUNTIME_HEAPTRC_LOG) >/dev/null || { cat $(ZLIB_NATIVE_RUNTIME_RUN_LOG); cat $(ZLIB_NATIVE_RUNTIME_HEAPTRC_LOG); exit 1; }
	@cat $(ZLIB_NATIVE_RUNTIME_RUN_LOG)
	@cat $(ZLIB_NATIVE_RUNTIME_HEAPTRC_LOG)
	@printf '\ncompress-audit-native-zlib-runtime=pass\n'

benchmark-compile:
	$(MAKE) -C $(CORE_ROOT)/benchmarks/nextpas.core.compress/bench_compress build
	@printf 'compress-benchmark-compile=pass\n'

benchmark-run:
	$(MAKE) -C $(CORE_ROOT)/benchmarks/nextpas.core.compress/bench_compress run
	@printf 'compress-benchmark-run=pass\n'

go-comparator-compile:
	cd $(CORE_ROOT)/benchmarks/nextpas.core.compress/bench_compress/compare_go && go test ./...
	@printf 'compress-go-comparator-compile=pass\n'

go-comparator-run:
	cd $(CORE_ROOT)/benchmarks/nextpas.core.compress/bench_compress/compare_go && go run .
	@printf 'compress-go-comparator-run=pass\n'

example-run:
	$(MAKE) -C $(CORE_ROOT)/examples/nextpas.core.compress/compress_roundtrip run
	@printf 'compress-example-run=pass\n'

example-native-compile:
	@mkdir -p $(EXAMPLE_NATIVE_BUILD_DIR)
	$(FPC) -MObjFPC -Sh -O2 -gl $(NATIVE_COMPILE_FLAGS) -FU$(EXAMPLE_NATIVE_BUILD_DIR) -FE$(EXAMPLE_NATIVE_BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src $(CORE_ROOT)/examples/nextpas.core.compress/compress_roundtrip/compress_roundtrip.lpr
	@printf 'compress-example-native-lz4-compile=pass\n'

heaptrc: build
	@rm -f $(RUN_LOG) $(HEAPTRC_LOG)
	@$(HEAPTRC_ENV) $(BUILD_DIR)/$(PROGRAM) > $(RUN_LOG) 2>&1 || { cat $(RUN_LOG); test ! -f $(HEAPTRC_LOG) || cat $(HEAPTRC_LOG); exit 1; }
	@grep -F '0 unfreed memory blocks' $(HEAPTRC_LOG) >/dev/null || { cat $(RUN_LOG); cat $(HEAPTRC_LOG); exit 1; }
	@cat $(RUN_LOG)
	@cat $(HEAPTRC_LOG)
	@printf '\ncompress-audit-heaptrc=pass\n'

docs-contract-run:
	$(MAKE) -C $(CORE_ROOT)/tests/nextpas.core.compress/test_compress_docs_contract test
	@printf 'compress-docs-contract-run=pass\n'

basic-test-run:
	$(MAKE) -C $(CORE_ROOT)/tests/nextpas.core.compress/test_compress test
	@printf 'compress-basic-test-run=pass\n'

deep-test-run:
	$(MAKE) -C $(CORE_ROOT)/tests/nextpas.core.compress/test_compress_deep test
	@printf 'compress-deep-test-run=pass\n'

clean:
	rm -rf $(BUILD_DIR) $(NATIVE_BUILD_DIR) $(NATIVE_RUNTIME_BUILD_DIR) $(EXAMPLE_NATIVE_BUILD_DIR) $(ZLIB_NATIVE_BUILD_DIR) $(ZLIB_NATIVE_RUNTIME_BUILD_DIR)
	$(MAKE) -C $(CORE_ROOT)/examples/nextpas.core.compress/compress_roundtrip clean
	$(MAKE) -C $(CORE_ROOT)/benchmarks/nextpas.core.compress/bench_compress clean
	$(MAKE) -C $(CORE_ROOT)/tests/nextpas.core.compress/test_compress clean
	$(MAKE) -C $(CORE_ROOT)/tests/nextpas.core.compress/test_compress_deep clean
	$(MAKE) -C $(CORE_ROOT)/tests/nextpas.core.compress/test_compress_docs_contract clean
