# nextpas.core.gtk2

**状态**: L2 家族 — 独立于 `gtk3` / `gtk4` / `window.gtk` / `webview.gtk`
**层级**: L2 系统能力（仅依赖 L0 `platform.dl` + FPC RTL）
**来源**: GTK2 / GLib / GObject 官方头（gtk/gtk.h, gdk/gdk.h, glib.h）

## 模块定位

`nextpas.core.gtk2` 为需要 GTK2 窗口壳的消费者提供最小 ABI 声明与动态装载层：

```
base ← ffi ← loader ← 门面
```

- `base`：常量（同 gtk3 常量子集，无逻辑）。
- `ffi`：GLib/GObject/GTK2 窗口壳函数指针 `var`（`cdecl`，无 `external`）。
- `loader`：家族内唯一触碰 `platform.dl` 的单元。
- 门面：`nextpas.core.gtk2` 聚合 re-export。

与 `nextpas.core.gtk4` / `window.gtk`（GTK3）互不依赖。

## GTK2 差异要点

- 窗口壳 ABI 同 gtk3 子集，唯 `gtk_widget_get_scale_factor` 在 GTK2 上不存在；
  该符号在 `ffi` 中仍声明为 `var`，在 `loader` 中以 `BindOpt` 可选绑定
  （缺失记 `nil`，整体装载仍可成功）。
- 其余 `gtk_window_*` / `gtk_widget_*` / `gdk_window_get_state` / `gtk_main` 等
  均与 gtk3 一致。

## 依赖方向

```
nextpas.core.gtk2.base        — 纯常量，无依赖
nextpas.core.gtk2.ffi         — 无家族内 uses
nextpas.core.gtk2.loader      — 唯一 uses platform.dl + ffi
nextpas.core.gtk2             — 门面 re-export base/ffi/loader
```

- `ffi` 禁 `uses` 家族其他单元。
- `loader` 唯一触 `platform.dl`，禁用 FPC `DynLibs`。

## 动态装载

- 探测序：`libgtk-x11-2.0.so.0` → `libgtk-x11-2.0.so`；并列 `libgobject-2.0.so.0` / `libglib-2.0.so.0`。
- 幂等：`TryLoadGtk2` 首装缓存，`UnloadGtk2` 全量释放。
- `gtk_widget_get_scale_factor` 以 `BindOpt` 可选绑定。

```pascal
uses nextpas.core.gtk2;

var
  LInfo: TGtk2LoadInfo;
begin
  if TryLoadGtk2(LInfo) and LInfo.Loaded then
    // ffi 函数指针已就绪（scale-factor 可能为 nil）
end;
```

## 测试

当前家族仅提供 ABI 声明与装载层；图形环境缺席时 `TryLoadGtk2` 返回 `False` 为正常路径。
