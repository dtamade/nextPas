# fuzz input parser — standalone fuzz harness
FPC := fpc
FPC_FLAGS := -MObjFPC -Sh -O2 -gl

.PHONY: test clean

test:
	$(FPC) $(FPC_FLAGS) -FE./ -FU./ -o./fuzz_input_parser fuzz_input_parser.lpr

clean:
	rm -f *.o *.ppu fuzz_input_parser
