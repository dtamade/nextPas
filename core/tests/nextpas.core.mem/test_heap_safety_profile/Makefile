# Opt-in HEAP_SAFETY profile smoke (not part of default lane_gate).
# Runs existing double-free detection under NEXTPAS_MEM_HEAP_SAFETY=1.
.PHONY: clean test

DOUBLE_FREE := ../test_double_free

clean:
	$(MAKE) -C $(DOUBLE_FREE) clean

test:
	NEXTPAS_MEM_HEAP_SAFETY=1 $(MAKE) -C $(DOUBLE_FREE) clean test
