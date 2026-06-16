PYTHON ?= python3

.PHONY: source-contracts test clean

source-contracts:
	$(MAKE) -C source_contracts test

test: source-contracts

clean:
	$(MAKE) -C source_contracts clean
