CORE_ROOT := ../../..
REPORT_DIR ?= $(CORE_ROOT)/build/projects/$(notdir $(CURDIR))
PYTHON ?= python3

.PHONY: test clean

test:
	@mkdir -p $(REPORT_DIR)
	$(PYTHON) -B check_rtl_isolation.py --self-test
	$(PYTHON) -B check_rtl_isolation.py --root $(CORE_ROOT) --json-file $(REPORT_DIR)/rtl_isolation.json --summary-line

clean:
	rm -rf $(REPORT_DIR) __pycache__
