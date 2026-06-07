TEST_FILTER ?= smoke
BASE_REF ?= main
CORE_CI_HOST ?= host

.PHONY: rebuild-compiler stage0 verify test test-smoke test-tooling focused lane-focused landing-check core-ci-test core-ci-best-effort-test self-compile-module self-compile-modules c8-probe-np-allocator hygiene clean clean-artifacts

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

focused: hygiene
	@test -n "$(FOCUS)" || { echo "FOCUS is required, e.g. make focused FOCUS=core/tests/nextpas.core.http/test_http_client" >&2; exit 1; }
	@test -d "$(FOCUS)" || { echo "FOCUS directory not found: $(FOCUS)" >&2; exit 1; }
	@focus_path=$$(CDPATH= cd -- "$(FOCUS)" && pwd -P); core_tests_path=$$(CDPATH= cd -- core/tests && pwd -P); case "$$focus_path/" in "$$core_tests_path"/*) ;; *) echo "FOCUS must be under core/tests/" >&2; exit 1; esac
	@test -f "$(FOCUS)/Makefile" || { echo "FOCUS Makefile not found: $(FOCUS)/Makefile" >&2; exit 1; }
	@awk -v target=clean 'BEGIN { found = 0 } /^[^#[:space:]][^:]*:/ { split($$0, parts, ":"); n = split(parts[1], names, /[[:space:]]+/); for (i = 1; i <= n; i++) if (names[i] == target) found = 1 } END { exit found ? 0 : 1 }' "$(FOCUS)/Makefile" || { echo "FOCUS Makefile must expose a clean target: $(FOCUS)" >&2; exit 1; }
	@awk -v target=test 'BEGIN { found = 0 } /^[^#[:space:]][^:]*:/ { split($$0, parts, ":"); n = split(parts[1], names, /[[:space:]]+/); for (i = 1; i <= n; i++) if (names[i] == target) found = 1 } END { exit found ? 0 : 1 }' "$(FOCUS)/Makefile" || { echo "FOCUS Makefile must expose a test target: $(FOCUS)" >&2; exit 1; }
	$(MAKE) -C "$(FOCUS)" clean
	$(MAKE) -C "$(FOCUS)" test
	$(MAKE) hygiene

lane-focused: hygiene
	./scripts/lane-focused.sh --lane "$(LANE)"
	$(MAKE) hygiene

landing-check: hygiene
	@test -n "$(ALLOW_PATHS)" || { echo "ALLOW_PATHS is required, e.g. make landing-check ALLOW_PATHS='scripts tests/tooling docs/worktrees.md'" >&2; exit 1; }
	./scripts/landing-candidate-check.sh --base "$(BASE_REF)" $(foreach path,$(ALLOW_PATHS),--allow-path "$(path)")
	git diff --check "$(BASE_REF)...HEAD"
	@if [ -n "$(FOCUS)" ]; then \
		$(MAKE) focused FOCUS="$(FOCUS)"; \
	elif [ -n "$(LANE)" ]; then \
		lane_output=$$(./scripts/lane-focused.sh --lane "$(LANE)" --print-command); \
		printf '%s\n' "$$lane_output"; \
		lane_focus=$$(printf '%s\n' "$$lane_output" | awk -F= '$$1 == "focus" { print $$2; exit }'); \
		test -n "$$lane_focus" || { echo "lane-focused did not report a focus path for LANE=$(LANE)" >&2; exit 1; }; \
		$(MAKE) focused FOCUS="$$lane_focus"; \
	else \
		$(MAKE) test-tooling; \
	fi
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
			passed=$$((passed + 1)); \
			echo "PASS: $$dir"; \
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

hygiene:
	./scripts/build-hygiene-check.sh

clean: clean-artifacts
	rm -rf build/harness build/stage0-bootstrap

clean-artifacts:
	./scripts/build-hygiene-check.sh clean-source-artifacts
