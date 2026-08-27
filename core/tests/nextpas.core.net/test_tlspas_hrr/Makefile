PROGRAM := test_tlspas_hrr
include ../../common.mk

PORT_P256 := 15557
PORT_P384 := 15558
PORT_BASE := 15556

test: build
	@BASE_PORT=$(PORT_BASE); P256_PORT=$(PORT_P256); P384_PORT=$(PORT_P384); \
	SERVER_PID=""; P256_PID=""; P384_PID=""; \
	exec 9>/tmp/tlspas_hrr_gate.lock || exit 1; \
	if ! flock -w 240 9; then echo "SKIP: hrr gate locked"; exit 0; fi; \
	if ! command -v openssl >/dev/null 2>&1; then echo "SKIP: openssl not available, synthetic only"; HEAPTRC='haltonnotreleased,log=$(BUILD_DIR)/$(PROGRAM).heaptrc' $(BUILD_DIR)/$(PROGRAM); RESULT=$$?; if [ -f $(BUILD_DIR)/$(PROGRAM).heaptrc ]; then grep -q '^0 unfreed memory blocks : 0$$' $(BUILD_DIR)/$(PROGRAM).heaptrc || { echo "[HEAPTRC] FAILED"; cat $(BUILD_DIR)/$(PROGRAM).heaptrc; exit 1; }; echo "[HEAPTRC] OK"; fi; exit $$RESULT; fi; \
	if [ ! -f /tmp/tlspas_hrr_server.key ] || [ ! -f /tmp/tlspas_hrr_server.crt ]; then openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout /tmp/tlspas_hrr_server.key -out /tmp/tlspas_hrr_server.crt -days 2 -nodes -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null || true; fi; \
	for P in $$BASE_PORT $$P256_PORT $$P384_PORT; do if command -v fuser >/dev/null 2>&1; then fuser -k $$P/tcp 2>/dev/null || true; fi; sleep 0.2; done; \
	(sleep 40) | openssl s_server -4 -key /tmp/tlspas_hrr_server.key -cert /tmp/tlspas_hrr_server.crt -accept $$BASE_PORT -www >/dev/null 2>&1 & SERVER_PID=$$!; sleep 0.5; \
	(sleep 40) | openssl s_server -4 -key /tmp/tlspas_hrr_server.key -cert /tmp/tlspas_hrr_server.crt -accept $$P256_PORT -www -groups P-256 >/dev/null 2>&1 & P256_PID=$$!; sleep 0.5; \
	(sleep 40) | openssl s_server -4 -key /tmp/tlspas_hrr_server.key -cert /tmp/tlspas_hrr_server.crt -accept $$P384_PORT -www -groups P-384 >/dev/null 2>&1 & P384_PID=$$!; sleep 1.0; \
	set +e; TLSPAS_HRR_BASE_PORT=$$BASE_PORT TLSPAS_HRR_P256_PORT=$$P256_PORT TLSPAS_HRR_P384_PORT=$$P384_PORT HEAPTRC='haltonnotreleased,log=$(BUILD_DIR)/$(PROGRAM).heaptrc' $(BUILD_DIR)/$(PROGRAM); RESULT=$$?; \
	kill $$SERVER_PID $$P256_PID $$P384_PID 2>/dev/null || true; wait $$SERVER_PID 2>/dev/null || true; wait $$P256_PID 2>/dev/null || true; wait $$P384_PID 2>/dev/null || true; \
	if [ $$RESULT -ne 0 ]; then exit $$RESULT; fi; \
	if [ -f $(BUILD_DIR)/$(PROGRAM).heaptrc ]; then grep -q '^0 unfreed memory blocks : 0$$' $(BUILD_DIR)/$(PROGRAM).heaptrc || { echo "[HEAPTRC] FAILED"; cat $(BUILD_DIR)/$(PROGRAM).heaptrc; exit 1; }; echo "[HEAPTRC] OK"; fi; exit 0
