COMPILER=fpc
FLAGS=-MObjFPC -Sh -O2 -gw -gl -Fu../../../src -Fi../../../src -Fi../../../src/core -Fi../../../src/core/time
TARGET=test_bench_parallel

.PHONY: all clean test

all: $(TARGET)

$(TARGET): $(TARGET).lpr
	$(COMPILER) $(FLAGS) $<

test: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET) *.o *.ppu
