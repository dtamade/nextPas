PROGRAM := test_tls13_e2e_openssl
include ../../common.mk

# Optional integration gate: spin up openssl s_server when available.
# Soft-skips (exit 0) when openssl is missing or the server fails to bind.
.PHONY: test
test: build
	@PORT=15555; \
	if ! command -v openssl >/dev/null 2>&1; then \
	  echo "SKIP: openssl not available for TLS 1.3 e2e"; \
	  exit 0; \
	fi; \
	if [ ! -f /tmp/tls13_test_cert.pem ] || [ ! -f /tmp/tls13_test_key.pem ]; then \
	  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
	    -keyout /tmp/tls13_test_key.pem -out /tmp/tls13_test_cert.pem \
	    -days 1 -nodes -subj "/CN=localhost" 2>/dev/null || true; \
	fi; \
	if [ ! -f /tmp/tls13_test_cert.pem ]; then \
	  echo "SKIP: could not generate e2e test certificate"; \
	  exit 0; \
	fi; \
	if command -v lsof >/dev/null 2>&1; then \
	  kill $$(lsof -ti :$$PORT) 2>/dev/null || true; \
	elif command -v fuser >/dev/null 2>&1; then \
	  fuser -k $$PORT/tcp 2>/dev/null || true; \
	fi; \
	sleep 0.3; \
	(sleep 30) | openssl s_server -4 \
	  -key /tmp/tls13_test_key.pem \
	  -cert /tmp/tls13_test_cert.pem \
	  -accept $$PORT -www >/dev/null 2>&1 & \
	SERVER_PID=$$!; \
	sleep 1.2; \
	if command -v ss >/dev/null 2>&1; then \
	  LISTENING=$$(ss -ltn 2>/dev/null | grep -c ":$$PORT " || true); \
	elif command -v lsof >/dev/null 2>&1; then \
	  LISTENING=$$(lsof -i :$$PORT >/dev/null 2>&1 && echo 1 || echo 0); \
	else \
	  LISTENING=1; \
	fi; \
	if [ "$$LISTENING" = "0" ]; then \
	  echo "SKIP: openssl s_server failed to start on port $$PORT"; \
	  kill $$SERVER_PID 2>/dev/null || true; \
	  wait $$SERVER_PID 2>/dev/null || true; \
	  exit 0; \
	fi; \
	set +e; \
	$(BUILD_DIR)/$(PROGRAM); \
	RESULT=$$?; \
	kill $$SERVER_PID 2>/dev/null || true; \
	wait $$SERVER_PID 2>/dev/null || true; \
	exit $$RESULT
