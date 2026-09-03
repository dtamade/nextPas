.PHONY: test test_bytes test_cursor test_stream test_source_contracts clean

test: test_source_contracts test_bytes test_cursor test_stream

test_bytes:
	$(MAKE) -C test_bytes test

test_cursor:
	$(MAKE) -C test_cursor test

test_stream:
	$(MAKE) -C test_stream test

test_source_contracts:
	$(MAKE) -C test_bytes_ops_source_contracts test

clean:
	$(MAKE) -C test_bytes clean
	$(MAKE) -C test_cursor clean
	$(MAKE) -C test_stream clean
	$(MAKE) -C test_bytes_ops_source_contracts clean
