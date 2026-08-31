PROGRAM := test_dialer
include ../../common.mk

# P5k: hermetic local fixture wired into `run` itself - spin up
# `openssl s_server` on port 15556 with a self-signed EC cert and dial
# 127.0.0.1 from the suite (VerifyNone client context for the self-signed
# peer). Every entry point (`make run`, `make test`, sweeps) therefore
# exercises real handshakes under the default heaptrc gate - the P5i
# opt-out is removed because the certificate-lifecycle verdict is now
# deterministic. Soft-skips when openssl is missing or bind fails.
.PHONY: clean run test
clean: clean-src
	rm -rf $(BUILD_DIR) $(WINE_BUILD_DIR)

FIXTURE_PORT := 15556
FIXTURE_CERT := /tmp/tlsdial_test_cert.pem
FIXTURE_KEY := /tmp/tlsdial_test_key.pem

run: build
	@if ! command -v openssl >/dev/null 2>&1; then \
	  echo "SKIP: openssl not available for dialer fixture"; \
	  exit 0; \
	fi; \
	if [ ! -f $(FIXTURE_CERT) ] || [ ! -f $(FIXTURE_KEY) ]; then \
	  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
	    -keyout $(FIXTURE_KEY) -out $(FIXTURE_CERT) \
	    -days 1 -nodes -subj "/CN=localhost" 2>/dev/null || true; \
	fi; \
	if [ ! -f $(FIXTURE_CERT) ]; then \
	  echo "SKIP: could not generate dialer fixture certificate"; \
	  exit 0; \
	fi; \
	if command -v lsof >/dev/null 2>&1; then \
	  kill $$(lsof -ti :$(FIXTURE_PORT)) 2>/dev/null || true; \
	elif command -v fuser >/dev/null 2>&1; then \
	  fuser -k $(FIXTURE_PORT)/tcp 2>/dev/null || true; \
	fi; \
	sleep 0.3; \
	(sleep 60) | openssl s_server -4 \
	  -key $(FIXTURE_KEY) \
	  -cert $(FIXTURE_CERT) \
	  -accept $(FIXTURE_PORT) -www >/dev/null 2>&1 & \
	SERVER_PID=$$!; \
	sleep 1.2; \
	if command -v ss >/dev/null 2>&1; then \
	  LISTENING=$$(ss -ltn 2>/dev/null | grep -c ":$(FIXTURE_PORT) " || true); \
	elif command -v lsof >/dev/null 2>&1; then \
	  LISTENING=$$(lsof -i :$(FIXTURE_PORT) >/dev/null 2>&1 && echo 1 || echo 0); \
	else \
	  LISTENING=1; \
	fi; \
	if [ "$$LISTENING" = "0" ]; then \
	  echo "SKIP: openssl s_server failed to start on port $(FIXTURE_PORT)"; \
	  kill $$SERVER_PID 2>/dev/null || true; \
	  wait $$SERVER_PID 2>/dev/null || true; \
	  exit 0; \
	fi; \
	rm -f $(HEAPTRC_DUMP); \
	set +e; \
	HEAPTRC='haltonnotreleased,log=$(HEAPTRC_DUMP)' $(BUILD_DIR)/$(PROGRAM); \
	RESULT=$$?; \
	set -e; \
	kill $$SERVER_PID 2>/dev/null || true; \
	wait $$SERVER_PID 2>/dev/null || true; \
	grep -q '^Heap dump by heaptrc unit' $(HEAPTRC_DUMP) || { echo "[HEAPTRC] FAILED: no heap dump written ($(HEAPTRC_DUMP))"; exit 1; }; \
	grep -q '^0 unfreed memory blocks : 0$$' $(HEAPTRC_DUMP) || { echo "[HEAPTRC] FAILED: unfreed blocks reported"; cat $(HEAPTRC_DUMP); exit 1; }; \
	echo "[HEAPTRC] OK"; \
	exit $$RESULT

test: run
