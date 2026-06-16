# compile-only opt-in gate:test_trig_host_compile_gate
# compile-only opt-in gate:test_impl_simd_win64_compile_gate
PROJECTS := test_api_surface test_impl_simd test_facade test_scalar test_symbol_scope test_trig test_vec test_mat test_quat test_transform test_easing test_random test_noise

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
