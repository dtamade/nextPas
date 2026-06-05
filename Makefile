.PHONY: rebuild-compiler self-compile-module c8-probe-np-allocator

rebuild-compiler:
	./scripts/rebuild-compiler.sh

self-compile-module: rebuild-compiler
	@test -n "$(MODULE)" || { echo "MODULE is required, e.g. make self-compile-module MODULE=rtl/core/mem/np_allocator.pas" >&2; exit 1; }
	./build/probe_self_compile_module.sh "$(MODULE)"

c8-probe-np-allocator: rebuild-compiler
	./build/probe_self_compile_module.sh rtl/core/mem/np_allocator.pas
