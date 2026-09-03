.PHONY: test test-base test-fake test-factory test-host test-gtk-runtime test-sdl2-runtime test-win32-runtime test-cocoa-runtime test-wasm-runtime test-android-runtime test-uikit-runtime test-qt-runtime test-polish test-stress test-live-arena test-source-contracts clean

test: test-source-contracts test-base test-fake test-factory test-host test-gtk-runtime test-sdl2-runtime test-win32-runtime test-cocoa-runtime test-wasm-runtime test-android-runtime test-uikit-runtime test-qt-runtime test-polish test-stress test-live-arena

test-source-contracts:
	$(MAKE) -C test_window_source_contracts test

test-base:
	$(MAKE) -C test_window_base clean test

test-fake:
	$(MAKE) -C test_window_fake clean test

test-factory:
	$(MAKE) -C test_window_factory clean test

test-host:
	$(MAKE) -C test_window_host clean test

test-gtk-runtime:
	$(MAKE) -C test_window_gtk_runtime clean test

test-sdl2-runtime:
	$(MAKE) -C test_window_sdl2_runtime clean test

test-win32-runtime:
	$(MAKE) -C test_window_win32_runtime clean test

test-cocoa-runtime:
	$(MAKE) -C test_window_cocoa_runtime clean test

test-wasm-runtime:
	$(MAKE) -C test_window_wasm_runtime clean test

test-android-runtime:
	$(MAKE) -C test_window_android_runtime clean test

test-uikit-runtime:
	$(MAKE) -C test_window_uikit_runtime clean test

test-qt-runtime:
	$(MAKE) -C test_window_qt_runtime clean test

test-polish:
	$(MAKE) -C test_window_polish clean test

test-stress:
	$(MAKE) -C test_window_stress clean test

test-live-arena:
	$(MAKE) -C test_window_live_arena clean test

clean:
	$(MAKE) -C test_window_base clean
	$(MAKE) -C test_window_fake clean
	$(MAKE) -C test_window_factory clean
	$(MAKE) -C test_window_host clean
	$(MAKE) -C test_window_gtk_runtime clean
	$(MAKE) -C test_window_sdl2_runtime clean
	$(MAKE) -C test_window_win32_runtime clean
	$(MAKE) -C test_window_cocoa_runtime clean
	$(MAKE) -C test_window_wasm_runtime clean
	$(MAKE) -C test_window_android_runtime clean
	$(MAKE) -C test_window_uikit_runtime clean
	$(MAKE) -C test_window_qt_runtime clean
	$(MAKE) -C test_window_polish clean
	$(MAKE) -C test_window_stress clean
	$(MAKE) -C test_window_live_arena clean
	$(MAKE) -C test_window_source_contracts clean
