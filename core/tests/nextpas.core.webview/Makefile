.PHONY: test test-contracts test-base test-bridge test-factory test-fake-eval test-fake-invoke test-fake-window test-gtk-loader test-gtk-backend test-vfs test-webview2-loader test-webview2-post test-wk-loader clean

test: test-contracts test-base test-bridge test-factory test-fake-eval test-fake-invoke test-fake-window test-gtk-loader test-gtk-backend test-vfs test-webview2-loader test-webview2-post test-wk-loader

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

test-vfs:
	$(MAKE) -C test_webview_vfs clean test

test-webview2-loader:
	$(MAKE) -C test_webview_webview2_loader clean test

test-webview2-post:
	$(MAKE) -C test_webview_webview2_post clean test

test-wk-loader:
	$(MAKE) -C test_webview_wk_loader clean test

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
	$(MAKE) -C test_webview_vfs clean
	$(MAKE) -C test_webview_webview2_loader clean
	$(MAKE) -C test_webview_webview2_post clean
	$(MAKE) -C test_webview_wk_loader clean
