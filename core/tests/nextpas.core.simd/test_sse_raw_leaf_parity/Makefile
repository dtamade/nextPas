# test_sse_raw_leaf_parity — compile-only test
FPC := fpc
CORE_ROOT := ../../..
FPC_FLAGS := -MObjFPC -Sh -O2 -gl -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/src

.PHONY: test clean

test:
	$(FPC) $(FPC_FLAGS) -FE./ -FU./ -o./test_sse_raw_leaf_parity test_sse_raw_leaf_parity.lpr

clean:
	rm -f *.o *.ppu test_sse_raw_leaf_parity
