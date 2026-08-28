# nextpas.core.window — CI 矩阵与平台诚实表

> 终局目标 `ci-matrix`：13 门在 Linux / Windows / macOS 三机均绿，`bench_dispatcher` 三机方差 <5%。
> 当前 `F3` 单机已固化，`Win/mac` 为 `compile-only + 探测 SKIP` 诚实降级，`residual` 透明记录。

## 1. 当前基线 (2026-08-28, Linux 44c)

| 门禁 | Linux | Windows (2022) | macOS (13/14) |
|------|-------|----------------|---------------|
| source-contracts (INV-3/4/5 + INV-RTL) | ✅ pass | — | — |
| base 8/0 | ✅ | — | — |
| fake 15/0 | ✅ | ✅ compile-only | ✅ compile-only |
| factory 13/0 | ✅ (ProbeGtk True via libgtk-3) | 🔶 SKIP (ProbeWin32 False→ecNotFound) compile-only pass | 🔶 SKIP (ProbeCocoa False) compile-only pass |
| gtk_runtime 3/0 | ✅ (Xvfb) | N/A | N/A |
| sdl2_runtime 3/0 | ✅ (libSDL2) | 🔶 SKIP (no SDL2) / compile-only | 🔶 SKIP |
| win32_runtime 2/0 | 🔶 SKIP (no user32) compile-only pass | ✅ 预期真跑 | N/A |
| cocoa_runtime 2/0 | 🔶 SKIP (no AppKit) compile-only pass | N/A | ✅ 预期真跑 |
| wasm/android/uikit 3/0 | 🔶 SKIP compile-only | 🔶 SKIP | 🔶 SKIP |
| stress 4×2000 | ✅ | — | — |
| host 7/0 | ✅ | — | — |
| bench_dispatcher | ✅ 7项中位见 BENCH.md | — | — |
| hygiene | ✅ | — | — |

## 2. 编译隔离证据

- `win32` / `cocoa` 全链路 `fpc -MObjFPC -Sh -Fu./core/src -Fi./core/src -Cn` 在 **Linux 上 compile-only pass**，无 `objectivec1` / `Windows` 直引，仅 `platform.dl + nextpas.core.window.live/queue + text.ansi` + `ffi/loader` 单点 `platform.dl`。
- `win32.loader` 探测 `user32.dll / libuser32`，`cocoa.loader` 探测 `libobjc / libdispatch / AppKit`，`TryLoad*` 缺席时 `IsAvailable=False` 诚实降级，`Create*` 抛 `EWindowBackendUnavailable(ecNotFound)`，不链接真系统库。
- `gtk` 家族 `libgtk-3/4 / libgtk-x11-2.0` 同理 `BindOpt` 诚实，`WindowBackendDiagnostics` 输出 `sonames + smart fallback gtk4>gtk3>gtk2`。

## 3. 三机理想矩阵 (F3 完整)

| Runner | 必跑 | 可选 (BindOpt) | 预期 |
|--------|------|----------------|------|
| ubuntu-22.04 + Xvfb | base/fake/factory/gtk/sdl2/stress/host/bench | win32/cocoa SKIP | 13 门全绿 |
| windows-2022 | base/fake/factory/win32/sdl2/stress/host | gtk/cocoa SKIP | 13 门全绿，bench 三机对比 |
| macos-13/14 | base/fake/factory/cocoa/sdl2/stress/host | win32/gtk SKIP | 13 门全绿 |

*`wasm/android/uikit` 三机均为 `SKIP` (需 Emscripten/Android NDK/Xcode 真宿主)，`bench` 仅 Linux 固化为权威，其余两机作 `ops/s` 对比。*

## 4. Residual 与回退

- **Runner 缺位**：若 `windows/macOS` runner 未就绪，`F3` 降为 `Linux + compile-only`，`registry` 保持 `focused-runtime`，`CI_MATRIX.md` 标注 `Linux-only ci-matrix` 并记录 `residual`，不阻塞 `F4`。
- **方差>5%**：固定 `cpufreq` + `isolcpus` + 5×中位，若仍超则回滚该波 `inline/queue` 改动。

## 5. 验证命令

```bash
make hygiene
make focused FOCUS=core/tests/nextpas.core.window/test_window_factory      # 13/0
make focused FOCUS=core/tests/nextpas.core.window/test_window_gtk_runtime # 3/0 (Xvfb)
make -C core/benchmarks/nextpas.core.window/bench_dispatcher bench        # 7 项
fpc -MObjFPC -Sh -Fu./core/src -Fi./core/src -Cn core/src/nextpas.core.window.win32.pas
fpc -MObjFPC -Sh -Fu./core/src -Fi./core/src -Cn core/src/nextpas.core.window.cocoa.pas
```

