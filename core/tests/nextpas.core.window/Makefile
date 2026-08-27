.PHONY: test test-base test-fake test-factory test-source-contracts clean

test: test-source-contracts test-base test-fake test-factory

test-source-contracts:
	$(MAKE) -C test_window_source_contracts test

test-base:
	$(MAKE) -C test_window_base clean test

test-fake:
	$(MAKE) -C test_window_fake clean test

test-factory:
	$(MAKE) -C test_window_factory clean test

clean:
	$(MAKE) -C test_window_base clean
	$(MAKE) -C test_window_fake clean
	$(MAKE) -C test_window_factory clean
	$(MAKE) -C test_window_source_contracts clean
