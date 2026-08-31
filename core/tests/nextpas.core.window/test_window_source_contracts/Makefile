CORE_ROOT := ../../..
SCRIPT := check_window_source_contracts.sh
.PHONY: test clean
test:
	bash $(SCRIPT) $(abspath $(CORE_ROOT))
	@printf '\nwindow-source-contracts=pass\n'
clean:
	@true
