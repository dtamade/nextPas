# flat_regression — batch runner for flattened test programs
# ===========================================================
# The flattened tests module (tests/nextpas.core.tls/*.pas) historically had
# no project Makefile, so the root `make test` matrix never ran them and they
# rotted (see scripts/flat-test-audit.sh for the classification used to build
# manifest.txt). This project re-wires the *verified* flattened programs into
# the matrix: manifest.txt lists one test name per line; each is compiled with
# the shared test flags and executed, and any failure fails `make test`.
#
# Only add entries that are proven green by flat-test-audit + a manual run:
# a red entry blocks the whole repo matrix, so the manifest is an explicit
# whitelist, never a directory scan.
#
# Runtime artifacts: tests run with the tests module as cwd (their relative
# asset paths assume it), so any file a test writes lands in the source tree.
# Known writer: test_capability_serialization exports capability_openssl.json/
# .xml into cwd; the run loop removes them after each entry so `make test`
# leaves the tree clean.

FPC ?= fpc
CORE_ROOT := ../../..
# abspath: run target cd's into the tests module (tests keep relative asset
# paths against that cwd), so BUILD_DIR must survive the directory change.
BUILD_DIR := $(abspath $(CORE_ROOT)/build/projects/nextpas.core.tls/flat_regression)
MANIFEST := manifest.txt
FPC_FLAGS := -MObjFPC -Sh -Sg -O2 -gl -gh -dHEAPTRC_ACTIVE -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/tests/shared

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	@if [ ! -f $(MANIFEST) ]; then echo "error: $(MANIFEST) missing" >&2; exit 1; fi
	@while read -r t; do \
		[ -z "$$t" ] && continue; \
		echo "building $$t"; \
		$(FPC) $(FPC_FLAGS) ../$$t.pas || exit 1; \
	done < $(MANIFEST)

run:
	@if [ ! -f $(MANIFEST) ]; then echo "error: $(MANIFEST) missing" >&2; exit 1; fi
	@fail=0; \
	while read -r t; do \
		[ -z "$$t" ] && continue; \
		if [ ! -x "$(BUILD_DIR)/$$t" ]; then echo "MISSING BIN: $$t"; fail=1; continue; fi; \
		echo "running $$t"; \
		if ! (cd .. && "$(BUILD_DIR)/$$t" >"$(BUILD_DIR)/$$t.out" 2>&1); then \
			echo "FAILED: $$t"; tail -20 "$(BUILD_DIR)/$$t.out"; fail=1; \
		fi; \
		rm -f ../capability_openssl.json ../capability_openssl.xml; \
	done < $(MANIFEST); \
	[ $$fail -eq 0 ] || { echo "flat_regression: FAILURES PRESENT"; exit 1; }; \
	echo "flat_regression: all manifest tests passed"

test: build run

clean:
	rm -rf $(BUILD_DIR)
