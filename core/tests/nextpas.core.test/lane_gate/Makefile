# test lane default gate: api + runner source-contracts + scale report
# Equivalent to: make -C core/tests/nextpas.core.test contracts
.PHONY: clean test

PARENT := ..

clean:
	$(MAKE) -C $(PARENT)/test_api_source_contracts clean
	$(MAKE) -C $(PARENT)/test_runner_source_contracts clean
	$(MAKE) -C $(PARENT)/test_scale_report clean

test:
	$(MAKE) -C $(PARENT) contracts
