PROGRAM := test_net_async_tlsfp
include ../../common.mk

# tooling (test_core_focused_makefiles) scans this Makefile text only — it does
# not expand include. Re-declare clean so suites that override `test:` still
# expose a clean target (same semantics as common.mk).
.PHONY: clean test
clean: clean-src
	rm -rf $(BUILD_DIR) $(WINE_BUILD_DIR)

# Integration gate: spin up openssl s_server (-www) as the independent
# peer for the full-handshake cases. Soft-skips when openssl is missing
# or the server fails to bind; the in-process cases always run.
# flock 串行化：固定端口 + 启动前 fuser -k 意味着并发运行会互相
# 杀死对方的 s_server（在途握手瞬间 RST → ERR_IO 假失败）；
# 排队等待即可，4 分钟拿不到锁按 SKIP 处理。
PORT := 15556

test: build
	@PORT=$(PORT); \
	SERVER_PID=""; \
	exec 9>/tmp/tls13_gate_$(PORT).lock || exit 1; \
	if ! flock -w 240 9; then \
	  echo "SKIP: another tlsfp e2e run holds the gate lock"; \
	  exit 0; \
	fi; \
	if ! command -v openssl >/dev/null 2>&1; then \
	  echo "SKIP: openssl not available for tlsfp e2e"; \
	else \
	  if [ ! -f /tmp/tlsfp_v2_ca.crt ] || [ ! -f /tmp/tlsfp_v2_ca.key ]; then \
	    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
	      -keyout /tmp/tlsfp_v2_ca.key -out /tmp/tlsfp_v2_ca.crt \
	      -days 2 -nodes -subj "/CN=tlsfp-test-ca" \
	      -addext "basicConstraints=critical,CA:TRUE" 2>/dev/null || true; \
	  fi; \
	  if [ ! -f /tmp/tlsfp_v2_server.crt ] && [ -f /tmp/tlsfp_v2_ca.crt ]; then \
	    printf "subjectAltName=DNS:localhost,IP:127.0.0.1\n" > /tmp/tlsfp_v2_san.ext; \
	    openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
	      -keyout /tmp/tlsfp_v2_server.key -out /tmp/tlsfp_v2_server.csr \
	      -nodes -subj "/CN=localhost" 2>/dev/null; \
	    openssl x509 -req -in /tmp/tlsfp_v2_server.csr \
	      -CA /tmp/tlsfp_v2_ca.crt -CAkey /tmp/tlsfp_v2_ca.key -CAcreateserial \
	      -out /tmp/tlsfp_v2_server.crt -days 2 -sha256 \
	      -extfile /tmp/tlsfp_v2_san.ext 2>/dev/null || true; \
	  fi; \
	  if [ ! -f /tmp/tlsfp_v2_otherca.crt ]; then \
	    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
	      -keyout /tmp/tlsfp_v2_otherca.key -out /tmp/tlsfp_v2_otherca.crt \
	      -days 2 -nodes -subj "/CN=tlsfp-test-other-ca" \
	      -addext "basicConstraints=critical,CA:TRUE" 2>/dev/null || true; \
	  fi; \
	  if [ ! -f /tmp/tlsfp_v2_server.crt ]; then \
	    echo "SKIP: could not generate e2e test certificate"; \
	  else \
	    if command -v lsof >/dev/null 2>&1; then \
	      kill $$(lsof -ti :$$PORT) 2>/dev/null || true; \
	    elif command -v fuser >/dev/null 2>&1; then \
	      fuser -k $$PORT/tcp 2>/dev/null || true; \
	    fi; \
	    sleep 0.3; \
	    (sleep 40) | openssl s_server -4 \
	      -key /tmp/tlsfp_v2_server.key \
	      -cert /tmp/tlsfp_v2_server.crt \
	      -accept $$PORT -www >/dev/null 2>&1 & \
	    SERVER_PID=$$!; \
	    sleep 1.2; \
	    LISTENING=1; \
	    if command -v ss >/dev/null 2>&1; then \
	      LISTENING=$$(ss -ltn 2>/dev/null | grep -c ":$$PORT " || true); \
	    elif command -v lsof >/dev/null 2>&1; then \
	      LISTENING=$$(lsof -i :$$PORT >/dev/null 2>&1 && echo 1 || echo 0); \
	    fi; \
	    if [ "$$LISTENING" = "0" ]; then \
	      echo "SKIP: openssl s_server failed to start on port $$PORT"; \
	      kill $$SERVER_PID 2>/dev/null || true; \
	      wait $$SERVER_PID 2>/dev/null || true; \
	      SERVER_PID=""; \
	    fi; \
	  fi; \
	fi; \
	set +e; \
	TLSFP_TRUST_BUNDLE=/tmp/tlsfp_v2_ca.crt \
	TLSFP_UNTRUSTED_BUNDLE=/tmp/tlsfp_v2_otherca.crt \
	HEAPTRC='haltonnotreleased,log=$(BUILD_DIR)/$(PROGRAM).heaptrc' $(BUILD_DIR)/$(PROGRAM); \
	RESULT=$$?; \
	if [ -n "$$SERVER_PID" ]; then \
	  kill $$SERVER_PID 2>/dev/null || true; \
	  wait $$SERVER_PID 2>/dev/null || true; \
	fi; \
	if [ $$RESULT -ne 0 ]; then exit $$RESULT; fi; \
	if [ -f $(BUILD_DIR)/$(PROGRAM).heaptrc ]; then \
	  grep -q '^0 unfreed memory blocks : 0$$' $(BUILD_DIR)/$(PROGRAM).heaptrc || { echo "[HEAPTRC] FAILED"; cat $(BUILD_DIR)/$(PROGRAM).heaptrc; exit 1; }; \
	  echo "[HEAPTRC] OK"; \
	fi; \
	exit 0
