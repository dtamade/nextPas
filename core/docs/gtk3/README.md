# nextpas.core.gtk3

**层级**: L2 系统能力（仅依赖 L0 `platform` 的 `platform.dl` 缝 + FPC RTL；被 L2 `window` 复用）
**Owner**: core-gtk lane（独立家族，与 `window` 解耦）
**状态**: 抽取自 `nextpas.core.window.gtk.*`，四件套已独立；`window` 为消费者
**依赖方向**: `base ← ffi ← loader ← 门面`

---

## 模块定位

`nextpas.core.gtk3` 是 GTK3 栈的独立 L2 家族，提供**可复用的 GTK3 动态装载与 ABI 声明底座**。

```
platform.dl(L0) ──► gtk3(L2) ──► window(L2) ──► webview(L3)/gpu(L3)/directui(L3)
                    (base/ffi/loader/门面)
```

- **抽取来源**：`core/src/nextpas.core.window.gtk.ffi.pas / loader.pas / gtk.pas`。
  `window.gtk.ffi` 仅承载窗口壳子集的 GLib/GTK 符号；`window.gtk.loader` 仅触 `platform.dl`。
  本次将该子集**原样搬运**为独立家族，`window` 侧不再拥有 GTK 私有 ABI，改为消费 `gtk3`。
- **L2 约束**：只依赖 `L0-L1`（实际仅 `platform.dl` + FPC RTL），禁止同层循环；同家族内 `base` 零依赖、`ffi` 仅依赖 `base`、`loader` 仅依赖 `ffi + platform.dl`、门面聚合。
- **不再触及内容引擎**：本家族仅装载 `libgtk-3 / libgobject-2.0 / libglib-2.0`，不含 WebKit/JSC（归 `webview`）。

---

## 文件布局

| 单元 | 职责 | 依赖 | 备注 |
|------|------|------|------|
| `nextpas.core.gtk3.base` | 常量与轻量类型根 | 仅 FPC RTL | 抽取 `GDK_WINDOW_STATE_*` / `GLIB_SOURCE_*` / `G_PRIORITY_DEFAULT` / `GTK_WINDOW_TOPLEVEL` + `gboolean/guint/gulong/guint32/gint` |
| `nextpas.core.gtk3.ffi` | ABI 声明层 | `gtk3.base` | 回调类型与 26 个函数指针变量，无逻辑无 `external` |
| `nextpas.core.gtk3.loader` | 动态装载 | `platform.dl` + `gtk3.ffi` | 家族内唯一触 `platform.dl` 的单元，`TryLoadGtk3` 幂等 |
| `nextpas.core.gtk3` | 门面 | `base` + `ffi` + `loader` | 纯 re-export：显式 `type` 别名 + `inline` 转发 `loader` 函数 |

---

## Sonames

```pascal
GGtkLib:      ['libgtk-3.so.0', 'libgtk-3.so']
GGobjectLib:  ['libgobject-2.0.so.0']
GGlibLib:     ['libglib-2.0.so.0']
```

- `TryDlOpen` 按数组顺序尝试 `platform_dl_load(..., [dlfLazy, dlfGlobal])`，首个成功即停。
- GTK 取双名兼容：发行版多提供 `libgtk-3.so.0`（soname）与 `libgtk-3.so`（devel 软链）；其余两库保持单名（与 `window.gtk.loader` 历史一致）。
- 三库必须全部打开成功才进入符号绑定阶段；任一缺失即 `ReleaseAll` 并返回 `False`。

---

## 符号集来源

官方头：`gtk/gtk.h` / `gdk/gdk.h` / `glib.h` / `gobject/gobject.h`（GTK3 3.x）。

子集仅含窗口壳必需的 26 个符号（与 `window.gtk.ffi` 一致），分为：

- **GLib**: `g_idle_add_full` / `g_source_remove` / `g_signal_connect_data` / `g_signal_handler_disconnect` / `g_timeout_add`
- **GObject**: `g_object_unref`
- **GTK3 窗口壳**: `gtk_init_check` / `gtk_window_new` / `gtk_window_set_title` / `gtk_window_get_title` / `gtk_window_set_default_size` / `gtk_window_set_resizable` / `gtk_window_resize` / `gtk_window_maximize` / `gtk_window_unmaximize` / `gtk_window_iconify` / `gtk_window_deiconify` / `gtk_window_is_maximized` / `gtk_widget_show_all` / `gtk_widget_hide` / `gtk_widget_get_visible` / `gtk_widget_get_scale_factor` / `gtk_widget_grab_focus` / `gtk_widget_get_window` / `gtk_widget_destroy` / `gtk_widget_get_allocated_width` / `gtk_widget_get_allocated_height` / `gdk_window_get_state` / `gtk_main` / `gtk_main_quit` / `gtk_main_iteration_do` / `gtk_events_pending`

未包含 WebKit/JSC、GDK-X11、cairo/pango 等；后续如需扩展，需在 `ffi` 新增 `var` 并在 `loader.BindAll` 追加 `BindReq`，保持 all-or-nothing。

---

## BindReq 清单

`loader.BindAll` 按以下顺序绑定，全部成功才算装载成功（任一缺失即 `ReleaseAll` 回滚）：

```pascal
BindReq(@g_idle_add_full, 'g_idle_add_full') and
BindReq(@g_source_remove, 'g_source_remove') and
BindReq(@g_signal_connect_data, 'g_signal_connect_data') and
BindReq(@g_signal_handler_disconnect, 'g_signal_handler_disconnect') and
BindReq(@g_timeout_add, 'g_timeout_add') and
BindReq(@g_object_unref, 'g_object_unref') and
BindReq(@gtk_init_check, 'gtk_init_check') and
BindReq(@gtk_window_new, 'gtk_window_new') and
BindReq(@gtk_window_set_title, 'gtk_window_set_title') and
BindReq(@gtk_window_get_title, 'gtk_window_get_title') and
BindReq(@gtk_window_set_default_size, 'gtk_window_set_default_size') and
BindReq(@gtk_window_set_resizable, 'gtk_window_set_resizable') and
BindReq(@gtk_window_resize, 'gtk_window_resize') and
BindReq(@gtk_window_maximize, 'gtk_window_maximize') and
BindReq(@gtk_window_unmaximize, 'gtk_window_unmaximize') and
BindReq(@gtk_window_iconify, 'gtk_window_iconify') and
BindReq(@gtk_window_deiconify, 'gtk_window_deiconify') and
BindReq(@gtk_window_is_maximized, 'gtk_window_is_maximized') and
BindReq(@gtk_widget_show_all, 'gtk_widget_show_all') and
BindReq(@gtk_widget_hide, 'gtk_widget_hide') and
BindReq(@gtk_widget_get_visible, 'gtk_widget_get_visible') and
BindReq(@gtk_widget_get_scale_factor, 'gtk_widget_get_scale_factor') and
BindReq(@gtk_widget_grab_focus, 'gtk_widget_grab_focus') and
BindReq(@gtk_widget_get_window, 'gtk_widget_get_window') and
BindReq(@gtk_widget_destroy, 'gtk_widget_destroy') and
BindReq(@gtk_widget_get_allocated_width, 'gtk_widget_get_allocated_width') and
BindReq(@gtk_widget_get_allocated_height, 'gtk_widget_get_allocated_height') and
BindReq(@gdk_window_get_state, 'gdk_window_get_state') and
BindReq(@gtk_main, 'gtk_main') and
BindReq(@gtk_main_quit, 'gtk_main_quit') and
BindReq(@gtk_main_iteration_do, 'gtk_main_iteration_do') and
BindReq(@gtk_events_pending, 'gtk_events_pending')
```

`BindReq` 经 `Sym(PAnsiChar(AName))` 在三库中按 `GGtkLib → GGobjectLib → GGlibLib` 依次 `TPlatformLibrary.Sym` 查找，`0` 表示命中。

---

## 探测语义

```pascal
type TGtk3LoadInfo = record Loaded: Boolean; end;
     TWindowGtkLoadInfo = TGtk3LoadInfo; // 兼容别名

function TryLoadGtk3(out AInfo: TGtk3LoadInfo): Boolean;
procedure UnloadGtk3;
function Gtk3LoadInfo: TGtk3LoadInfo;
function Gtk3IsLoaded: Boolean;

// 兼容：历史 window 侧名称（inline 转发）
function TryLoadWindowGtk(out AInfo: TWindowGtkLoadInfo): Boolean; inline;
procedure UnloadWindowGtk; inline;
function WindowGtkLoadInfo: TWindowGtkLoadInfo; inline;
function WindowGtkIsLoaded: Boolean; inline;
```

- **幂等**：`GLoaded=True` 时 `TryLoadGtk3` 直接返回 `GInfo` 与 `True`，不二次 `dlopen`。
- **互斥**：`GLoading` 护栏防止重入探测（返回 `False`）。
- **原子性**：`TryDlOpen` 三库与 `BindAll` 26 符号任一失败即 `ReleaseAll` 清空句柄，`GLoaded` 保持 `False`。
- **生命周期**：`UnloadGtk3` 对空为幂等 `Exit`；释放三库句柄并 `Default(TGtk3LoadInfo)` 清零。
- **查询**：`Gtk3LoadInfo` 返回 `GInfo` 快照；`Gtk3IsLoaded` 返回 `GLoaded` 进程全局标志。
- **零链接依赖**：全程经 `nextpas.core.platform.dl`，禁用 FPC `DynLibs`；缺库/缺符号不抛异常，仅返回 `False`，由调用方决定降级。

---

## 与 window 的关系

```
gtk3.base ──► gtk3.ffi ──► gtk3.loader ──► gtk3(门面)
                                         ▲
                                         │ uses
                              window.gtk(后端) ── window.factory ── window(门面)
```

- **`window` 消费 `gtk3`**：`nextpas.core.window.gtk` 原为 GTK 后端实现（含 `g_idle_add_full` dispatcher + 6 信号挂接）。抽取后，`window.gtk` 的 ABI/装载部分迁移至 `gtk3`，剩余窗口壳逻辑仍在 `window.gtk`，但 `uses` 改为 `gtk3.ffi / gtk3.loader`（由另一 agent 负责迁移，本 lane 不改 `window` 侧文件）。
- **符号唯一真相**：`gtk3.ffi` 为 GTK3 符号的唯一声明地，`window.gtk.ffi` 保留期仅作兼容；新代码应 `uses nextpas.core.gtk3` 或 `nextpas.core.gtk3.ffi`。
- **装载唯一真相**：`gtk3.loader` 为唯一 `platform.dl` 触点，`window.gtk.loader` 保留期转发至 `gtk3.loader`。
- **门面互不循环**：`gtk3` 门面不 `uses` 任何 `window.*`；`window` 门面可 `uses gtk3`（L2→L2 单向依赖，禁止反向）。
- **测试**：`window` 的 `test_window_gtk_runtime` 未来应通过 `gtk3` 的 `TryLoadGtk3` 探测 GTK 可用性；`gtk3` 自身不新增运行时测试，仅提供底座能力。

---

## 使用示例

```pascal
uses
  nextpas.core.gtk3;

var
  Info: TGtk3LoadInfo;
begin
  if TryLoadGtk3(Info) and Info.Loaded then
  begin
    // 符号已绑定，可直接调用 ffi 指针或经 window.gtk 后端建窗
    if gtk_init_check(nil, nil) <> 0 then
      // ...
  end;
end;
```

兼容 `window` 历史路径仍可用：

```pascal
var WI: TWindowGtkLoadInfo;
begin
  if TryLoadWindowGtk(WI) then ... // inline 转发至 TryLoadGtk3
end;
```

---

## 约束与门禁

- `base` 仅常量与类型，`uses` 仅 FPC RTL；`ffi` 仅 `uses base`，无逻辑无 `external`；`loader` 仅 `uses platform.dl + ffi`。
- 生产单元禁止出现 `Windows / BaseUnix / Unix / DynLibs / ctypes`。
- `make hygiene` 与 `scripts/build-hygiene-check.sh` 禁止源码树产物。

## 参见

- `core/src/nextpas.core.gtk3.*.pas` — 实现
- `core/src/nextpas.core.window.gtk.*.pas` — 消费者（另一 lane 迁移中）
- `core/src/nextpas.core.platform.dl.pas` — 唯一原语
