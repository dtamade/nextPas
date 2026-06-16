CORE_ROOT := ../../..
REPORT_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.config/test_config_format_contracts
PYTHON ?= python3

.PHONY: test clean

test:
	@mkdir -p $(REPORT_DIR)
	$(PYTHON) check_config_format_contracts.py --root $(CORE_ROOT) --json-file $(REPORT_DIR)/config_format_contracts.json --summary-line

clean:
	rm -rf $(REPORT_DIR)
