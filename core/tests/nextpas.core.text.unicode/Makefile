# nextpas.core.text.unicode — aggregated gate (M1)
# Usage: make -C core/tests/nextpas.core.text.unicode gate

.PHONY: gate gate-conformance gate-unit help

CONFORMANCE := \
	test_conformance_normalize \
	test_conformance_grapheme \
	test_conformance_word \
	test_conformance_sentence \
	test_conformance_line \
	test_conformance_bidi_character \
	test_conformance_bidi \
	test_conformance_collate \
	test_conformance_case \
	test_conformance_idna \
	test_conformance_confusables

UNIT := \
	test_case \
	test_normalize \
	test_property \
	test_collate \
	test_data \
	test_enhance \
	test_grapheme_uax29 \
	test_idna \
	test_confusable

help:
	@echo "Targets:"
	@echo "  make gate              - all conformance + unit (M1 product gate)"
	@echo "  make gate-conformance  - official harnesses only"
	@echo "  make gate-unit         - unit suites only"

gate: gate-conformance gate-unit
	@echo ""
	@echo "=== text.unicode gate: ALL GREEN ==="

gate-conformance:
	@failed=0; \
	for t in $(CONFORMANCE); do \
	  echo ""; \
	  echo ">>> $$t"; \
	  $(MAKE) -C $$t clean test || failed=1; \
	done; \
	if [ $$failed -ne 0 ]; then echo "gate-conformance FAILED"; exit 1; fi

gate-unit:
	@failed=0; \
	for t in $(UNIT); do \
	  echo ""; \
	  echo ">>> $$t"; \
	  $(MAKE) -C $$t clean test || failed=1; \
	done; \
	if [ $$failed -ne 0 ]; then echo "gate-unit FAILED"; exit 1; fi
