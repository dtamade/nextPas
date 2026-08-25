CORE_ROOT := ../../..
SCRIPT := check_webview_contracts.sh
.PHONY: test clean
test:
	bash $(SCRIPT) $(abspath $(CORE_ROOT))
	@printf '\nwebview-contracts=pass\n'
clean:
	@true
