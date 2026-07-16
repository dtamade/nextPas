# Main focused gate: correctness + public surface contracts.
# Side suites (not in PROJECTS):
#   test_http_benchmarks  — timing/comparator harness, not a correctness gate
#   test_http_examples    — example smoke, slower / env-dependent
#   test_http_smoke       — broad smoke; prefer focused suites
#   test_http_integration — long multi-surface integration
#   test_http_tls_real    — needs OpenSSL host env; residual backend leaks owned by tls
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
	test_http_hsts \
	test_http_static \
	test_http_client \
	test_http_contract \
	test_http_registry \
	test_http_h1scan \
	test_http_h1parser \
	test_http_h1fast \
	test_http_h1writer \
	test_http_h1chunked \
	test_http_h1outbound \
	test_http_server \
	test_http_security \
	test_http_stress \
	test_http_h2_frame \
	test_http_h2_types \
	test_http_h2_hpack \
	test_http_h2_hpack_block \
	test_http_h2_stream \
	test_http_h2_session \
	test_http_h2_client \
	test_http_websocket \
	test_http_websocket_client \
	test_http_fuzz \
	test_http_https_redirect

.PHONY: test clean $(PROJECTS)

test:
	@status=0; \
	for project in $(PROJECTS); do \
		echo "=== $$project ==="; \
		if ! $(MAKE) -C $$project clean test; then \
			status=1; \
		fi; \
		echo ""; \
	done; \
	exit $$status

clean:
	@for project in $(PROJECTS); do \
		[ ! -d "$$project" ] || $(MAKE) -C $$project clean; \
	done

$(PROJECTS):
	$(MAKE) -C $@ test
