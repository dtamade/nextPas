# nextpas.core.qt5pas

**层级**: L2 家族（依赖 L0-L1；被 `window` 后端复用）
**Owner**: core-window lane
**状态**: S2 占位 — 四件套已落地（base/ffi/loader/门面），无后端实现
**对标**: Lazarus `libQt5Pas.so`（Qt5 绑定）+ `QWidget`/`QApplication`/`QWindow`

---

## 家族定位

`nextpas.core.qt5pas` 是对系统已装 `libQt5Pas.so` 的**直接绑定**家族（非自包装）。

```
window.base/window.intf ──► window.qt5pas（待立项，后端实现）
                                ▲
                   qt5pas.base/qt5pas.ffi/qt5pas.loader（本家族，占位）
                                ▲
                          platform.dl（唯一动态装载缝）
```

与 `nextpas.core.qt`（自包装 `vendors/libnextpas-qt`）互为**替代路径**，见 `core/docs/qt/README.md` 的 deferred 触发条件。

## 单元布局

| 单元 | 职责 |
|------|------|
| `nextpas.core.qt5pas.base` | 常量/类型占位：句柄别名、窗口标志、默认几何、错误族 |
| `nextpas.core.qt5pas.ffi` | ABI 声明层：`QApplication_*`/`QWidget_*`/`QWindow`/`Hook` 函数指针 `var cdecl`，无 `external` 无逻辑 |
| `nextpas.core.qt5pas.loader` | 唯一触 `platform.dl`：`TryLoadQt5Pas`/`UnloadQt5Pas`/`Qt5PasLoadInfo`/`Qt5PasIsLoaded`，`BindReq` 窗口必需符号 |
| `nextpas.core.qt5pas` | 门面 re-export |

依赖方向：`base ← ffi ← loader ← 门面`；`ffi` 禁 `uses` 其他家族单元。

## ABI 来源

- `lcl/interfaces/qt5/cbindings/qt5pas.h`（Lazarus 源码）
- `libQt5Pas.so` 导出表（`nm -D libQt5Pas.so.1`）

本家族仅截取**窗口壳必需的 8-10 个核心符号**（保持与 `window.gtk.ffi` 同风格）：

- `QApplication_create` / `destroy` / `exec` / `quit`
- `QWidget_create` / `setWindowTitle` / `windowTitle` / `resize` / `show` / `hide` / `close` / `destroy` / `winId` / `isVisible`
- `QWindow_create`（可选替代路径，Wayland/高分屏补充）
- 信号连接基础：`QApplication_hook_create` / `QWidget_hook_create` / `Hook_destroy`

> 注：Qt5Pas 真实签名中 `setWindowTitle` 入参为 `PWideString`（`WideString*`），本桩为保持与 `window` UTF-8 约定一致，ffi 侧暂以 `PWideChar` 声明，装载期按同名符号绑定，不影响 `BindReq` 判定。

## 装载纪律

- `sonames = ['libQt5Pas.so.1','libQt5Pas.so','libQt5Pas.so.1.2.14']`，按序探测。
- 窗口必需符号 `BindReq`，缺一即 `TryLoadQt5Pas = False`；`QWindow`/hook 为 `BindOpt` 增强，不计入必需集。
- 进程级幂等：`GLoaded`/`GLoading` 双标志，`ReleaseAll` 统一 `platform_dl_release`。
- 生产单元（`window.qt5pas`）禁止直触 `platform.dl` / `DynLibs` / `BaseUnix` 等，平台真相收敛在 `ffi`+`loader`。

## 契约

- `base`/`ffi` 零后端依赖，`ffi` 无逻辑无 `external`（INV-5）。
- `loader` 为家族内**唯一**触 `platform.dl` 的单元（INV-4）。
- 后端（待立项）需实现 `IWindow` 全量方法，`NativeHandle` 诚实表与 `window.gtk` 对齐（X11 `WId`/Wayland nil）。

## 路线

- **当前**：四件套占位，`window.qt5pas` 后端 deferred。
- **触发后端立项**：当 `IWindow` 需在 Qt5 环境提供原生能力且 `libQt5Pas` 满足必需集时。
- **若 `libQt5Pas` 不满足 IWindow 最小集或目标为 Qt6-only**，转 `nextpas.core.qt` 自包装路径（见 `core/docs/qt/README.md`）。
