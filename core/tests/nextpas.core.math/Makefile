PROJECTS := test_api_surface test_facade test_scalar test_symbol_scope test_trig test_vec test_mat test_quat test_transform test_easing test_random

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
