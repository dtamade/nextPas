# test_marshal — compile-only test
FPC := fpc
FPC_FLAGS := -MObjFPC -Sh -O2 -gl

.PHONY: test clean

test:
	$(FPC) $(FPC_FLAGS) -FE./ -FU./ -o./test_marshal test_marshal.lpr

clean:
	rm -f *.o *.ppu test_marshal
