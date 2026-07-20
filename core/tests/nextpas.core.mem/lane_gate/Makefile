# mem lane default gate: usability guardrails + contract matrix
.PHONY: clean test

GUARDRAILS := ../test_usability_guardrails
CONTRACT := ../test_contract_matrix

clean:
	$(MAKE) -C $(GUARDRAILS) clean
	$(MAKE) -C $(CONTRACT) clean

test:
	$(MAKE) -C $(GUARDRAILS) clean test
	$(MAKE) -C $(CONTRACT) clean test
