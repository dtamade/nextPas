# nextpas.core.qt（自包装 C shim）

**层级**: L2 家族（依赖 L0-L1；被 `window` 后端复用）
**Owner**: core-window lane
**状态**: deferred 桩 — 四件套已落地（base/ffi/loader/门面），`vendors/libnextpas-qt` 未立项
**对标**: 自包装 `libnextpas-qt.so`（Qt5/Qt6 稳定 C ABI，收敛 `QApplication`/`QWidget`/`QWindow` 差异）

---

## 家族定位

`nextpas.core.qt` 是对**自包装 C shim** `vendors/libnextpas-qt` 的绑定家族，与 `nextpas.core.qt5pas`（直绑 `libQt5Pas.so`）互为替代：

```
window.base/window.intf ──► window.qt（待立项，后端实现）
                                ▲
                        qt.base/qt.ffi/qt.loader（本家族，桩）
                                ▲
                          platform.dl（唯一动态装载缝）
                                ▲
                     vendors/libnextpas-qt（C shim，deferred）
```

shim 的价值：以极薄的 C 层收敛 Qt 版本差异（Qt5 vs Qt6）与 `libQt5Pas` 的非标准 `PWideString` 签名，向 Pascal 暴露**版本无关的 `qt_*` C ABI**（`PAnsiChar` 标题、`int` 几何、`double` scale 等），后端只需对 `qt.ffi` 编程。

## 单元布局

| 单元 | 职责 |
|------|------|
| `nextpas.core.qt.base` | 常量/类型占位（deferred）：句柄别名、默认几何、错误族 |
| `nextpas.core.qt.ffi` | ABI 声明层：`qt_app_*`/`qt_window_*`/`qt_dispatcher_post` 函数指针 `var cdecl`，**全部 `BindOpt`**，桩阶段缺席不报错 |
| `nextpas.core.qt.loader` | 唯一触 `platform.dl`：`TryLoadQt`/`UnloadQt`/`QtLoadInfo`/`QtIsLoaded`，**全部 `BindOpt`**，`Loaded` 仅当主库加载成功 |
| `nextpas.core.qt` | 门面 re-export |

依赖方向：`base ← ffi ← loader ← 门面`；`ffi` 禁 `uses` 其他家族单元；`loader` 唯一触 `platform.dl`。

## ABI（桩）

`qt.ffi` 声明的稳定 C ABI（shim 立项后冻结）：

- `qt_app_create` / `destroy` / `run` / `quit`
- `qt_window_create` / `destroy` / `set_title` / `get_title` / `set_bounds` / `get_bounds` / `show` / `hide` / `close` / `is_visible` / `get_scale` / `get_native_handle` / `dispatcher_post`

全部 `cdecl` 函数指针 `var`，无 `external` 无逻辑。桩阶段 `loader` 以 `BindOpt` 绑定，符号缺席置 `nil` 不视为装载失败。

## 装载纪律

- `sonames = ['libnextpas-qt.so','libnextpas-qt.so.1']`
- `TryLoadQt`：`platform_dl_load` 主库成功即 `Loaded=True`，随后 `BindOpt` 全部符号（缺席不报错）。
- 进程级幂等，`ReleaseAll` 统一 `platform_dl_release`。
- `ffi` 禁 `uses` 家族其他单元；`loader` 唯一触 `platform.dl`。

## Deferred 触发条件

本家族与 `vendors/libnextpas-qt` 的立项**同时触发**，任一满足即立项：

1. **Qt6-only 环境**：目标发行版仅提供 Qt6，`libQt5Pas.so` 不可用或不再维护，需自包装以支持 Qt6。
2. **qt5pas 不满足 IWindow 最小集**：`libQt5Pas.so` 的可用符号/签名无法覆盖 `IWindow` 窗口壳最小集（标题/几何/可见性/`winId`/`scale`/`NativeHandle`/`dispatcher_post`），或 `PWideString` 签名与 `window` UTF-8 约定冲突无法低成本桥接。

触发前**不创建** `vendors/libnextpas-qt` 目录与任何 C 源码；触发后按以下契约交付：

- `vendors/libnextpas-qt/CMakeLists.txt` + `qt_shim.c`（薄封装，`find_package(Qt6/Qt5)`）
- C shim 仅做 `QString::fromUtf8`/`toUtf8`、`QWidget`/`QWindow` 几何与 `QMetaObject::invokeMethod` 调度，无业务逻辑
- `qt.ffi` 符号表冻结为上述 `qt_*` 列表，`qt.loader` 改 `BindReq` 窗口必需集
- 后端 `window.qt` 实现 `IWindow` + `IWindowDispatcher`（`qt_dispatcher_post` 经 `QMetaObject::invokeMethod` 回主线程）

## 与 qt5pas 的选择

| 维度 | `qt5pas`（直绑） | `qt`（自包装） |
|------|----------------|----------------|
| 依赖 | 系统 `libQt5Pas.so`（Lazarus 生态） | 自带 `libnextpas-qt.so`（需自编译） |
| Qt 版本 | 仅 Qt5 | Qt5 + Qt6（shim 收敛） |
| 签名 | `PWideString`（WideString*） | `PAnsiChar` UTF-8（shim 已转码） |
| 维护成本 | 零（随 Lazarus） | 需维护 `vendors/libnextpas-qt` |
| 适用 | Qt5 环境且符号满足 IWindow | Qt6-only 或 qt5pas 不满足最小集 |

默认优先 `qt5pas`；触发条件满足时切 `qt`。
