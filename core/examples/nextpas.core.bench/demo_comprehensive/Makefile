COMPILER=fpc
FLAGS=-MObjFPC -Sh -O2 -gw -gl -Fu../../../src -Fi../../../src
TARGET=demo_comprehensive

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(TARGET).lpr
	$(COMPILER) $(FLAGS) $<

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET) *.o *.ppu
