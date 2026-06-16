PROJECTS := \
	test_http_h2_frame \
	test_http_h2_types \
	test_http_h2_hpack \
	test_http_h2_hpack_block \
	test_http_h2_stream \
	test_http_h2_session \
	test_http_h2_client \
	test_http_base \
	test_http_headers \
	test_http_url \
	test_http_message \
	test_http_router \
	test_http_client \
	test_http_h1parser \
	test_http_h1fast \
	test_http_h1scan \
	test_http_h1writer \
	test_http_h1outbound \
	test_http_h1chunked \
	test_http_server \
	test_http_contract \
	test_http_security \
	test_http_registry \
	test_http_static \
	test_http_middleware \
	test_http_middlewares \
	test_http_websocket \
	test_http_integration \
	test_http_smoke

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
