.PHONY: test test-source-contracts test-facade test-contracts test-typinfo-minimal test-sysutils-minimal clean

test: test-source-contracts test-facade test-contracts test-typinfo-minimal test-sysutils-minimal

test-source-contracts:
	$(MAKE) -C test_system_source_contracts test

test-facade:
	$(MAKE) -C test_system_facade clean test

test-contracts:
	$(MAKE) -C test_system_contracts clean test

test-typinfo-minimal:
	$(MAKE) -C test_system_typinfo_minimal clean test

test-sysutils-minimal:
	$(MAKE) -C test_system_sysutils_minimal clean test

clean:
	$(MAKE) -C test_system_facade clean
	$(MAKE) -C test_system_contracts clean
	$(MAKE) -C test_system_typinfo_minimal clean
	$(MAKE) -C test_system_sysutils_minimal clean
