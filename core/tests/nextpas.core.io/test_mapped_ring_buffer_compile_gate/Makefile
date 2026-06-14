.PHONY: test
test:
	mkdir -p ../../../build/projects/nextpas.core.io/test_mapped_ring_buffer_compile_gate
	fpc -MObjFPC -Sh -O2 -Cn \
	  -FU../../../build/projects/nextpas.core.io/test_mapped_ring_buffer_compile_gate \
	  -FE../../../build/projects/nextpas.core.io/test_mapped_ring_buffer_compile_gate \
	  -Fu../../../src -Fi../../../src \
	  test_mapped_ring_buffer_compile_gate.lpr
