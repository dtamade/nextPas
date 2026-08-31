PROGRAM := test_usability_guardrails
include ../../common.mk

# Suite-specific source-contract checks, chained ahead of the binary run
# exactly as before the common.mk migration.
.PHONY: test-source-contract
test-source-contract:
	bash check_usability_docs.sh
	bash check_consumer_audit_contracts.sh
	bash check_alloc_error_raises.sh
	bash check_mem_rtl_isolation.sh

test: test-source-contract run
