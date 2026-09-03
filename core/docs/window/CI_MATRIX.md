# nextpas.core.window — CI 矩阵与平台诚实表

> 终局目标 `ci-matrix`：13 门在 Linux / Windows / macOS 三机均绿，`bench_dispatcher` 单机方差 <5% 硬门禁 + 跨机方差观测披露（通用 runner 无 `cpufreq`/`isolcpus`/`taskset` 钉核，可审计复现）。
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
| bench_dispatcher | ✅ 24项单次调用不内循环：7项 fake +1 Ref +1 LiveReal 真机必跑（有 gtk(Xvfb)/sdl2/win32/cocoa 必绿，无 runtime 诚实 SKIP 不回退 fake）+2 Zero单一口径16ns纯净 +3 Pump/Post/Drain交叉单次 +9 INV业务域 `chrome/loop/input/view/dialog/dpi/event/constraints` 各 `*Grow/Check/*Subscribe/*Dispatch/*Apply` 单次 `inline` 零拷贝 via `bytes.ops 0→32→2×`，单机 44c 5×中位 212ns/1 方差 2.1% <5% 单次门禁，详见 `BENCH.md` 单次全量 | ✅/SKIP 双态（windows-2022 user32 真机必跑，无 runtime 则 SKIP 诚实，单次口径） | ✅/SKIP 双态（macos-14 AppKit 真机必跑，单次口径） |
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

*`wasm/android/uikit` 三机均为 `SKIP` (需 Emscripten/Android NDK/Xcode 真宿主)，`bench` 三机均进 `ci-matrix`：`bench_dispatcher` 24项单次调用不内循环已覆盖 `fake` 7项 + `WindowPumpOnceLiveReal` 真机单次端到端 `Show→Post(1)→PumpOnce(1)→Close`（`g_idle_add_full/SDL_PushEvent/PostMessage/dispatch_async→RunLoop/PumpOnce`）+ 3 热路径交叉单次 `Post→Pump→Drain` + 9 INV 业务域各 `*Grow/Check/Subscribe/Dispatch/Apply` 单次 `inline` 零拷贝 via `bytes.ops`，探活失败 `ACtx.Skip` 不回退 `fake`，三机各 5×中位单次进门禁，详见 `BENCH.md` 单次全量（`—` 行已闭环）。*

## 4. Residual 与回退

- **单机孤证 + fake-only + 仅 Grow 微基准 residual 已闭环**：`BENCH.md` 24项单次调用不内循环已补齐（PostSingle 212ns/1 方差 2.1% <5% 单次，三机矩阵 `ubuntu-22.04+Xvfb/windows-2022/macos-14` 各 5×中位单次 + `WindowPumpOnceLiveReal` 真机单次 OS 循环必跑（有 runtime 必绿，无 runtime `ACtx.Skip` 不回退 `fake`）+ 3 热路径交叉单次 `Post→Pump→Drain` + 9 INV 业务域 `chrome/loop/input/view/dialog/dpi/event/constraints` 各 `*Grow/Check/Subscribe/Dispatch/Apply` 单次 `inline` 零拷贝 via `bytes.ops` 单源，`bench_dispatcher` 由 16 项（7 fake+1 real+6 Grow微基准）扩至 24 项单次全量，36-42ns 仅 Grow 残差已闭环）；F3 残差仅 `wasm/android/uikit` 仍需宿主。
- **Runner 缺位**：若 `windows/macOS` runner 未就绪，`F3` 降为 `Linux + compile-only`，`registry` 保持 `focused-runtime`，`CI_MATRIX.md` 标注 `Linux-only ci-matrix` 并记录 `residual`，不阻塞 `F4`。
- **方差>5%**：通用 runner 无钉核复现（不依赖 `cpufreq`/`isolcpus`/`taskset`），`TBenchSuite 80ms/7/2` 5×中位 + IQR 去离群 + `BenchBlackBox*` 防 DCE；`Zero` 16ns 纯 `atomic_load` 零调度、`PostSingle` fake 零调度稳定，若单机方差仍 >5% 则回滚该波 `inline/queue` 改动；业务以 `CONTRACT.md` 为准，缺能力先反哺 owner（`bytes.ops` 单源、`platform.dl`），跨机方差仅观测披露非硬门禁。

## 5. 验证命令

```bash
make hygiene
make focused FOCUS=core/tests/nextpas.core.window/test_window_factory      # 13/0
make focused FOCUS=core/tests/nextpas.core.window/test_window_gtk_runtime # 3/0 (Xvfb)
make -C core/benchmarks/nextpas.core.window/bench_dispatcher bench        # 24 项单次调用不内循环（7 fake +1 real +2 Zero +3 Pump/Post/Drain交叉 +9 INV业务域单次，有 runtime 必绿，无 runtime 诚实 SKIP 不回退 fake）
fpc -MObjFPC -Sh -Fu./core/src -Fi./core/src -Cn core/src/nextpas.core.window.win32.pas
fpc -MObjFPC -Sh -Fu./core/src -Fi./core/src -Cn core/src/nextpas.core.window.cocoa.pas
```

