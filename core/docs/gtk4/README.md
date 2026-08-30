# nextpas.core.gtk4

**状态**: L2 家族 — 独立于 `gtk3` / `window.gtk` / `webview.gtk`
**层级**: L2 系统能力（仅依赖 L0 `platform.dl` + FPC RTL）
**来源**: GTK4 / GLib / GObject 官方头（gtk/gtk.h, gdk/gdk.h, glib.h）

## 模块定位

`nextpas.core.gtk4` 为需要 GTK4 窗口壳的消费者提供最小 ABI 声明与动态装载层：

```
base ← ffi ← loader ← 门面
```

- `base`：常量（`GTK_WINDOW_TOPLEVEL` 等），注明 GTK4 差异。
- `ffi`：GLib/GObject/GTK4 窗口壳函数指针 `var`（`cdecl`，无 `external`）。
- `loader`：家族内唯一触碰 `platform.dl` 的单元，运行时探测与符号绑定。
- 门面：`nextpas.core.gtk4` 聚合 re-export。

与 `nextpas.core.gtk2` / `window.gtk`（GTK3）互不依赖。

## GTK4 差异要点

- `GTK_WINDOW_TOPLEVEL = 0` 数值同 GTK3，但 GTK4 中 `GtkWindowType` 已弃用；
  新代码应以 `gtk_window_new` + `gtk_window_set_child` 构造。
- `gtk_container_add` 移除，改 `gtk_window_set_child` / `gtk_window_get_child`。
- `gtk_widget_show_all` 语义收缩，改 `gtk_widget_set_visible` / `gtk_widget_show`。
- `gdk_window_get_state` 更名为 `gdk_surface_get_state`（`GdkWindow → GdkSurface`）。
- `gtk_window_present` 为呈现窗口的推荐路径。
- 以上 GTK4 特有符号在 `ffi` 中以 `var` 声明，在 `loader` 中以 `BindOpt` 可选绑定
  （缺失不导致整体失败，仅记 `nil`）。

## 依赖方向

```
nextpas.core.gtk4.base        — 纯常量，无依赖
nextpas.core.gtk4.ffi         — 无家族内 uses
nextpas.core.gtk4.loader      — 唯一 uses platform.dl + ffi
nextpas.core.gtk4             — 门面 re-export base/ffi/loader
```

- `ffi` 禁 `uses` 家族其他单元。
- `loader` 唯一触 `platform.dl`，禁用 FPC `DynLibs`。
- 生产单元禁止出现 `Windows` / `BaseUnix` / `Unix` 等 raw host units。

## 动态装载

- 探测序：`libgtk-4.so.1` → `libgtk-4.so` → `libgtk-4.so.0`；并列 `libgobject-2.0.so.0` / `libglib-2.0.so.0`。
- 幂等：`TryLoadGtk4` 首次成功后缓存，后续调用直接复用；`UnloadGtk4` 全量释放。
- 绑定：`BindReq` 必需符号缺失即整体失败并 `ReleaseAll`；`BindOpt` 仅对 GTK4 特有符号。

```pascal
uses nextpas.core.gtk4;

var
  LInfo: TGtk4LoadInfo;
begin
  if TryLoadGtk4(LInfo) and LInfo.Loaded then
    // ffi 函数指针已就绪
end;
```

## 测试

当前家族仅提供 ABI 声明与装载层，无窗口逻辑；测试以 `platform.dl` 可用性探测为主。
图形环境缺席时 `TryLoadGtk4` 返回 `False` 为正常业务路径。
