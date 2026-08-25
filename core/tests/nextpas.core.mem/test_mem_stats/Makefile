PROGRAM := test_mem_stats
include ../../common.mk

# Suite-specific source-contract checks, chained ahead of the binary run
# exactly as before the common.mk migration.
.PHONY: test-source-contract
test-source-contract:
	bash check_stats_atomic_reset.sh

test: test-source-contract run
