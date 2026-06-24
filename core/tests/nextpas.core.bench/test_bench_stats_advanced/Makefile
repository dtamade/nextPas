COMPILER=fpc
FLAGS=-MObjFPC -Sh -O2 -gw -gl -Fu../../../src -Fi../../../src
TARGET=test_bench_stats_advanced

.PHONY: all clean test

all: $(TARGET)

$(TARGET): $(TARGET).lpr
	$(COMPILER) $(FLAGS) $<

test: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET) *.o *.ppu
