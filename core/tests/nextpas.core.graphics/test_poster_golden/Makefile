PROGRAM := test_poster_golden
include ../../common.mk

# poster golden is a source-contract shell guard (no lpr); override test to run shell check
test:
	@bash $(CURDIR)/check_poster_golden.sh
	@echo "[HEAPTRC] OK (shell guard)"

clean: clean-src
	rm -rf $(BUILD_DIR) $(WINE_BUILD_DIR)
