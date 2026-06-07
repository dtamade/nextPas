TEST_FILTER ?= smoke

.PHONY: rebuild-compiler stage0 verify test test-smoke test-tooling self-compile-module self-compile-modules c8-probe-np-allocator hygiene clean clean-artifacts

rebuild-compiler:
	./scripts/rebuild-compiler.sh
	$(MAKE) hygiene

stage0: rebuild-compiler

verify: hygiene
	./build/verify_local.sh
	$(MAKE) hygiene

test: hygiene
	./tests/run_all_tests.sh --filter "$(TEST_FILTER)"
	$(MAKE) hygiene

test-smoke:
	$(MAKE) test TEST_FILTER=smoke

test-tooling: hygiene
	$(MAKE) -C tests/tooling test
	$(MAKE) hygiene

self-compile-module: rebuild-compiler
	@test -n "$(MODULE)" || { echo "MODULE is required, e.g. make self-compile-module MODULE=rtl/core/mem/np_allocator.pas" >&2; exit 1; }
	./build/probe_self_compile_module.sh "$(MODULE)"

self-compile-modules: rebuild-compiler
	./build/compile_compiler_modules.sh

c8-probe-np-allocator: rebuild-compiler
	./build/probe_self_compile_module.sh rtl/core/mem/np_allocator.pas

hygiene:
	./scripts/build-hygiene-check.sh

clean: clean-artifacts
	rm -rf build/harness build/stage0-bootstrap

clean-artifacts:
	./scripts/build-hygiene-check.sh clean-source-artifacts
