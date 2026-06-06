.PHONY: test test-source-contracts test-facade clean

test: test-source-contracts test-facade

test-source-contracts:
	$(MAKE) -C test_system_source_contracts test

test-facade:
	$(MAKE) -C test_system_facade clean test

clean:
	$(MAKE) -C test_system_facade clean
