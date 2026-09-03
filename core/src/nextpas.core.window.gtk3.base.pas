unit nextpas.core.window.gtk3.base;

{** @desc GTK3 宿主侧 window.base 承载：按需存在的 GtkWindow 句柄载体与零拷贝 inline 转换。
       非独立 L2 gtk3 家族的复刻——真实 GTK 类型/常量归 nextpas.core.gtk3.base
       （L2 独立家族 base←ffi←loader 不知 window，单向依赖 window 消费）；
       本单元归 window 域，仅承载 window 侧句柄视图，依赖 window.base 单源，
       守四件套 base←ffi←loader 分离与 L0-L3 单向，不混淆 host-owner。
       职责：TGtkWindowHandle 别名 + 零拷贝句柄互转 + 有效性；
       通用窗口类型仍归 window.base；base 保持纯数据类型不侵入 L1，零 L1 行为。
       性能：句柄互转/判定 inline 零拷贝/零额外调用（纯指针 cast，O(1)均摊）；守四件套 base←impl。
       稳定性：句柄生命周期归 GTK（gtk_widget_destroy），window 侧只读持有、Close 置 nil 不释放，不丢资源。 *}

{$I nextpas.core.settings.inc}
interface

uses
  nextpas.core.window.base;

type
  {** GtkWindow* 不透明句柄载体，生命周期归 GTK，window 侧只读持有、Close 置 nil 不释放。 *}
  TGtkWindowHandle = type Pointer;

{** 零拷贝句柄互转：纯指针 cast，inline 零开销、无分配/无拷贝；复用 window.base 单源句柄定义。 *}
function GtkWindowHandleFromNative(const AHandle: TWindowNativeHandle): TGtkWindowHandle; inline;
function GtkNativeFromWindowHandle(const AHandle: TGtkWindowHandle): TWindowNativeHandle; inline;
function GtkWindowHandleIsValid(const AHandle: TGtkWindowHandle): Boolean; inline;

implementation

function GtkWindowHandleFromNative(const AHandle: TWindowNativeHandle): TGtkWindowHandle; inline;
begin
  Result := TGtkWindowHandle(AHandle);
end;

function GtkNativeFromWindowHandle(const AHandle: TGtkWindowHandle): TWindowNativeHandle; inline;
begin
  Result := TWindowNativeHandle(AHandle);
end;

function GtkWindowHandleIsValid(const AHandle: TGtkWindowHandle): Boolean; inline;
begin
  Result := AHandle <> nil;
end;

end.
