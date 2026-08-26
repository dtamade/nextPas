.PHONY: test test-contracts test-base test-bridge test-factory test-fake-eval test-fake-invoke test-fake-window test-gtk-loader test-gtk-backend clean

test: test-contracts test-base test-bridge test-factory test-fake-eval test-fake-invoke test-fake-window test-gtk-loader test-gtk-backend

test-contracts:
	$(MAKE) -C contracts test

test-base:
	$(MAKE) -C test_webview_base clean test

test-bridge:
	$(MAKE) -C test_webview_bridge clean test

test-factory:
	$(MAKE) -C test_webview_factory clean test

test-fake-eval:
	$(MAKE) -C test_webview_fake_eval clean test

test-fake-invoke:
	$(MAKE) -C test_webview_fake_invoke clean test

test-fake-window:
	$(MAKE) -C test_webview_fake_window clean test

test-gtk-loader:
	$(MAKE) -C test_webview_gtk_loader clean test

test-gtk-backend:
	$(MAKE) -C test_webview_gtk_backend clean test

clean:
	$(MAKE) -C contracts clean
	$(MAKE) -C test_webview_base clean
	$(MAKE) -C test_webview_bridge clean
	$(MAKE) -C test_webview_factory clean
	$(MAKE) -C test_webview_fake_eval clean
	$(MAKE) -C test_webview_fake_invoke clean
	$(MAKE) -C test_webview_fake_window clean
	$(MAKE) -C test_webview_gtk_loader clean
	$(MAKE) -C test_webview_gtk_backend clean
