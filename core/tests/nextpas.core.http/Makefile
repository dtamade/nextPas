# Main focused gate: correctness + public surface contracts.
# Side suites (not in PROJECTS — run via make focused FOCUS=... when needed):
#   test_http_benchmarks  — timing/comparator harness, not a correctness gate
#   test_http_examples    — example smoke, slower / env-dependent
#   test_http_smoke       — broad smoke; prefer focused suites
#   test_http_integration — long multi-surface integration
#   test_http_tls_real    — needs OpenSSL host env; side suite (not main gate)
#   bench_http_h2         — H2 bench harness, not a correctness gate
#   test_http_threaded_host — multi-OS host smoke (make test / http-host-ci-matrix.sh);
#                             truth=host-runtime; NOT scale-ready / NOT IOCP
#   test_http_threaded_wine — Win64+Wine smoke (make wine-runtime-smoke; *_wine path);
#                             NOT real-Windows / NOT Windows scale-ready
# Era3 theme suites (also in PROJECTS; extracted from client/server monoliths):
#   test_http_client_redirect / test_http_client_body_helpers
#   test_http_server_expect / test_http_server_chunk
PROJECTS := \
	test_http_base \
	test_http_url \
	test_http_headers \
	test_http_message \
	test_http_form \
	test_http_cookie \
	test_http_router \
	test_http_middleware \
	test_http_middlewares \
	test_http_stream \
	test_http_sse \
	test_http_mem \
	test_http_hsts \
	test_http_static \
	test_http_client \
	test_http_client_redirect \
	test_http_client_body_helpers \
	test_http_contract \
	test_http_registry \
	test_http_h1scan \
	test_http_h1parser \
	test_http_h1fast \
	test_http_h1writer \
	test_http_h1chunked \
	test_http_h1outbound \
	test_http_server \
	test_http_server_expect \
	test_http_server_chunk \
	test_http_security \
	test_http_stress \
	test_http_h2_frame \
	test_http_h2_types \
	test_http_h2_hpack \
	test_http_h2_hpack_block \
	test_http_h2_stream \
	test_http_h2_session \
	test_http_h2_client \
	test_http_h2_facade \
	test_http_h2_tls_alpn \
	test_http_h1_tls_server \
	test_http_soak \
	test_http_q3_matrix \
	test_http_https_smoke \
	test_http_websocket \
	test_http_websocket_client \
	test_http_websocket_room \
	test_http_fuzz \
	test_http_https_redirect

.PHONY: test clean $(PROJECTS)

# Failed-suite summary at the end: a mid-log failure must not be silently
# attributed to the last suite when only the log tail is inspected.
test:
	@status=0; failed=""; \
	for project in $(PROJECTS); do \
		echo "=== $$project ==="; \
		if ! $(MAKE) -C $$project clean test; then \
			status=1; \
			failed="$$failed $$project"; \
		fi; \
		echo ""; \
	done; \
	if [ -n "$$failed" ]; then \
		echo "FAILED SUITES:$$failed"; \
	else \
		echo "ALL $(words $(PROJECTS)) SUITES GREEN"; \
	fi; \
	exit $$status

clean:
	@for project in $(PROJECTS); do \
		[ ! -d "$$project" ] || $(MAKE) -C $$project clean; \
	done

$(PROJECTS):
	$(MAKE) -C $@ test
