TEST_FILTER ?= smoke
BASE_REF ?= main
CORE_CI_HOST ?= host

.PHONY: rebuild-compiler stage0 stage0-heap-debug-recipe verify test test-smoke test-tooling test-compiler-incremental-cache test-compiler-constructor-typing test-incremental-gate test-compiler-system-intrinsics test-compiler-rec-str-abi test-compiler-astatestr-fail test-compiler-erroutput-fd test-compiler-write-i64-fd test-compiler-unit-init-chain test-compiler-unit-fini-body test-compiler-unit-lifecycle-llvm m2-two-hop m2-a-ready m2-llvm-smoke m2-ladder focused lane-focused landing-check core-ci-test core-ci-best-effort-test self-compile-module self-compile-modules c8-probe-np-allocator system-projection-check system-projection-sync hygiene clean clean-artifacts contract bench-module-test bench-scorecard-smoke

rebuild-compiler:
	./scripts/rebuild-compiler.sh
	$(MAKE) hygiene

contract:
	./scripts/run-all-contract-checks.sh

stage0: rebuild-compiler

# Fresh-process doctor projection under NEXTPAS_MEM_HEAP_DEBUG / NEXTPAS_MEM_DEBUG.
# Requires build/stage0-bootstrap/nextpas (run make rebuild-compiler first).
stage0-heap-debug-recipe:
	./scripts/stage0-heap-debug-env-recipe.sh

verify: hygiene contract
	$(MAKE) test-compiler-incremental-cache
	$(MAKE) test-compiler-constructor-typing
	$(MAKE) test-incremental-gate
	$(MAKE) test-compiler-system-intrinsics
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

test-compiler-incremental-cache: hygiene
	./compiler/tests/run_incremental_cache_framing.sh
	./compiler/tests/run_incremental_cache_entry_identity.sh
	$(MAKE) hygiene

test-compiler-constructor-typing: hygiene
	./compiler/tests/run_semantic_constructor_type_infer.sh
	$(MAKE) hygiene

test-incremental-gate: hygiene
	./tests/regression/verify_incremental.sh
	$(MAKE) hygiene

test-compiler-system-intrinsics: hygiene system-projection-check
	./compiler/tests/run_system_intrinsic_self_aliases_test.sh
	$(MAKE) hygiene

test-compiler-rec-str-abi: hygiene
	bash tests/regression/verify_compiler_rec_str_abi_focused.sh
	$(MAKE) hygiene

# Batch 26: multi-arg WriteLn + inline string sret (not M2-A).
test-compiler-astatestr-fail: hygiene
	bash tests/regression/verify_compiler_astatestr_fail_focused.sh
	$(MAKE) hygiene

# Batch 27: ErrOutput/StdErr → fd 2 host-free write routing (not M2-A).
test-compiler-erroutput-fd: hygiene
	bash tests/regression/verify_compiler_erroutput_fd_focused.sh
	$(MAKE) hygiene

# Batch 29: write_i64_decimal(value, fd) integer write to stderr (not M2-A).
test-compiler-write-i64-fd: hygiene
	bash tests/regression/verify_compiler_write_i64_fd_focused.sh
	$(MAKE) hygiene

# --- host-free unit lifecycle gates (D3) ---
# REQUIRE: scripts force --toolchain-binding linux-x86_64-to-linux-x86_64-llvm and
# anti-masquerade (backend-family=llvm, primary=llvm-stable; refuse fpc-stage0-host).
# Default `nextpas build` without that binding is host FPC — NOT host-free evidence.
# Do NOT change the global default toolchain binding from these targets.

# D3 host-free multi-unit unit_init side-effect (LLVM binding; not host FPC; not ledger raise).
test-compiler-unit-init-chain: hygiene
	bash tests/regression/verify_compiler_unit_init_chain.sh
	$(MAKE) hygiene

# D3 host-free multi-unit unit_fini body IR + executable oracle (LLVM binding).
test-compiler-unit-fini-body: hygiene
	bash tests/regression/verify_compiler_unit_fini_body.sh
	$(MAKE) hygiene

# D3 host-free unit_lifecycle_pass under LLVM (store i64→i32 trunc; not ledger raise).
test-compiler-unit-lifecycle-llvm: hygiene
	bash tests/regression/verify_compiler_unit_lifecycle_llvm.sh
	$(MAKE) hygiene

# --- M2 executable two-hop (excellence plan M2; not host self-compile probes) ---
# REQUIRE: scripts force --toolchain-binding linux-x86_64-to-linux-x86_64-llvm.
# Host self-compile / stage2-bootstrap module lists are NOT M2 evidence.
# M2-0 green: m2-two-hop (a-ready + llvm-smoke). A→B only when ladder L3 closes.

m2-two-hop: hygiene
	bash scripts/m2-two-hop.sh --phase a-ready --phase llvm-smoke
	$(MAKE) hygiene

m2-a-ready:
	bash scripts/m2-two-hop.sh --phase a-ready

m2-llvm-smoke:
	bash scripts/m2-two-hop.sh --phase a-ready --phase llvm-smoke

m2-ladder:
	bash scripts/m2-two-hop.sh --phase a-ready --phase ladder

focused: hygiene
	@test -n "$(FOCUS)" || { echo "FOCUS is required, e.g. make focused FOCUS=core/tests/nextpas.core.http/test_http_client" >&2; exit 1; }
	@test -d "$(FOCUS)" || { echo "FOCUS directory not found: $(FOCUS)" >&2; exit 1; }
	@focus_path=$$(CDPATH= cd -- "$(FOCUS)" && pwd -P); core_tests_path=$$(CDPATH= cd -- core/tests && pwd -P); case "$$focus_path/" in "$$core_tests_path"/*) ;; *) echo "FOCUS must be under core/tests/" >&2; exit 1; esac
	@test -f "$(FOCUS)/Makefile" || { echo "FOCUS Makefile not found: $(FOCUS)/Makefile" >&2; exit 1; }
	@$(MAKE) -C "$(FOCUS)" --dry-run clean >/dev/null 2>&1 || { echo "FOCUS Makefile must expose a clean target: $(FOCUS)" >&2; exit 1; }
	@$(MAKE) -C "$(FOCUS)" --dry-run test >/dev/null 2>&1 || { echo "FOCUS Makefile must expose a test target: $(FOCUS)" >&2; exit 1; }
	$(MAKE) -C "$(FOCUS)" clean
	$(MAKE) -C "$(FOCUS)" test
	$(MAKE) hygiene

lane-focused: hygiene
	./scripts/lane-focused.sh --lane "$(LANE)"
	$(MAKE) hygiene

# nextpas.core.bench module gate (all suites under core/tests/nextpas.core.bench)
bench-module-test: hygiene
	$(MAKE) -C core/tests/nextpas.core.bench clean test
	$(MAKE) hygiene

# Lightweight scorecard smoke (single fast track; needs fpc + go)
bench-scorecard-smoke:
	bash core/docs/bench/scripts/run-scorecard-subset.sh --tracks inttohex --summary

landing-check: hygiene
	@test -n "$(ALLOW_PATHS)" || { echo "ALLOW_PATHS is required, e.g. make landing-check ALLOW_PATHS='scripts tests/tooling docs/worktrees.md'" >&2; exit 1; }
	@set -e; \
	candidate_log=$$(mktemp); \
	trap 'rm -f "$$candidate_log"' EXIT HUP INT TERM; \
	./scripts/landing-candidate-check.sh --base "$(BASE_REF)" $(foreach path,$(ALLOW_PATHS),--allow-path "$(path)") >"$$candidate_log"; \
	cat "$$candidate_log"; \
	if grep -q '^landing-candidate=absorbed$$' "$$candidate_log"; then exit 0; fi; \
	git diff --check "$(BASE_REF)...HEAD"; \
	if [ -n "$(FOCUS)" ]; then \
		$(MAKE) focused FOCUS="$(FOCUS)"; \
	elif [ -n "$(LANE)" ]; then \
		lane_output=$$(./scripts/lane-focused.sh --lane "$(LANE)" --print-command); \
		printf '%s\n' "$$lane_output"; \
		lane_focus=$$(printf '%s\n' "$$lane_output" | awk -F= '$$1 == "focus" { print $$2; exit }'); \
		test -n "$$lane_focus" || { echo "lane-focused did not report a focus path for LANE=$(LANE)" >&2; exit 1; }; \
		$(MAKE) focused FOCUS="$$lane_focus"; \
	else \
		$(MAKE) test-tooling BASE_REF=main; \
	fi; \
	$(MAKE) hygiene

core-ci-test:
	$(MAKE) -C core test
	cd core && FPC="$${FPC:-fpc}" benchmarks/nextpas.core.tui/run_all.sh

core-ci-best-effort-test:
	@cd core && \
	total=0; passed=0; skipped=0; first_fail=""; log_file=$$(mktemp); \
	trap 'rm -f "$$log_file"' EXIT HUP INT TERM; \
	for mk in $$(find tests -mindepth 2 -name Makefile | sort); do \
		dir=$$(dirname "$$mk"); \
		total=$$((total + 1)); \
		if $(MAKE) -C "$$dir" test >"$$log_file" 2>&1; then \
			if grep -q 'SKIP:' "$$log_file"; then \
				skipped=$$((skipped + 1)); \
				echo "SKIP: $$dir"; \
			else \
				passed=$$((passed + 1)); \
				echo "PASS: $$dir"; \
			fi; \
		else \
			skipped=$$((skipped + 1)); \
			if [ -z "$$first_fail" ]; then \
				first_fail="$$dir"; \
				echo "SKIP: $$dir (first failure details below)"; \
				tail -20 "$$log_file"; \
			else \
				echo "SKIP: $$dir"; \
			fi; \
		fi; \
	done; \
	rm -f "$$log_file"; \
	echo ""; \
	echo "=== $(CORE_CI_HOST): $$passed passed, $$skipped skipped, $$total total ==="; \
	if [ "$$passed" -eq 0 ]; then exit 1; fi

self-compile-module: rebuild-compiler
	@test -n "$(MODULE)" || { echo "MODULE is required, e.g. make self-compile-module MODULE=rtl/core/mem/np_allocator.pas" >&2; exit 1; }
	./build/probe_self_compile_module.sh "$(MODULE)"

self-compile-modules: rebuild-compiler
	./build/compile_compiler_modules.sh

c8-probe-np-allocator: rebuild-compiler
	./build/probe_self_compile_module.sh rtl/core/mem/np_allocator.pas

system-projection-check:
	bash scripts/system-projection.sh check linux-x86_64

system-projection-sync:
	bash scripts/system-projection.sh sync linux-x86_64

hygiene:
	./scripts/build-hygiene-check.sh

clean: clean-artifacts
	rm -rf build/harness build/stage0-bootstrap

clean-artifacts:
	./scripts/build-hygiene-check.sh clean-source-artifacts
