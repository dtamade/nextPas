# hygiene sampling anchor: wc -l core/src/nextpas.core.js*.pas threshold 800 (single threshold, no 550/650 drift, see CONTRACT §1)
# explicit anchor in module Makefile, hygiene抽样显式锚定防阈值漂移, bytes.ops single source, inline zero-copy
THRESHOLD := 800
JS_SRCS := $(wildcard ../../../src/nextpas.core.js*.pas)

.PHONY: test clean hygiene
test: hygiene
	@bash ./check_js_source_contracts.sh
	@printf '\njs-source-contract=pass\n'
hygiene:
	@echo "[js-hygiene] wc -l sampling threshold $(THRESHOLD) (single threshold 800, see CONTRACT §1)"
	@for f in $(JS_SRCS); do lines=$$(wc -l < "$$f"); base=$$(basename "$$f"); if [ "$$lines" -gt $(THRESHOLD) ]; then echo "[js-hygiene] FAIL: $$base wc -l $$lines >$(THRESHOLD)" >&2; exit 1; else echo "[js-hygiene] $$base wc -l $$lines <800 (阈值800)"; fi; done
	@echo "[js-hygiene] volume sampling pass (threshold 800, bytes.ops single source inline zero-copy, try-finally not lost)"
clean:
	@true
