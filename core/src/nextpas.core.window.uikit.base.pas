unit nextpas.core.window.uikit.base;

{** @desc UIKit 基类型：按需存在的 UIWindow 句柄载体与零拷贝 inline 转换。
       非机械 4 件套占位：仅承载 UIWindow 句柄别名与句柄互转，
       真实职责归本单元；通用窗口类型（TWindowOptions/TWindowEvent 等）仍归
       window.base 单源，避免薄 re-export 掩盖无真实职责的机械创建。
       性能：句柄互转/判定 inline 零拷贝/零额外调用（纯指针 cast，O(1)均摊）；base 纯数据类型，零 L1 行为，守四件套 base←impl。
       稳定性：句柄生命周期归 UIKit（UIWindow），window 侧只读持有、Close 置 nil 不释放，不丢资源。 *}

{$I nextpas.core.settings.inc}
interface

uses
  nextpas.core.window.base;

type
  {** UIWindow* 不透明句柄载体，生命周期归 UIKit，window 侧只读持有、Close 置 nil 不释放。 *}
  TUIKitNativeWindow = type Pointer;

{** 零拷贝句柄互转：纯指针 cast，inline 零开销、无分配/无拷贝；复用 window.base 单源句柄定义。 *}
function UIKitNativeFromWindowHandle(const AHandle: TWindowNativeHandle): TUIKitNativeWindow; inline;
function WindowHandleFromUIKitNative(const AHandle: TUIKitNativeWindow): TWindowNativeHandle; inline;
function UIKitNativeIsValid(const AHandle: TUIKitNativeWindow): Boolean; inline;

implementation

function UIKitNativeFromWindowHandle(const AHandle: TWindowNativeHandle): TUIKitNativeWindow; inline;
begin
  Result := TUIKitNativeWindow(AHandle);
end;

function WindowHandleFromUIKitNative(const AHandle: TUIKitNativeWindow): TWindowNativeHandle; inline;
begin
  Result := TWindowNativeHandle(AHandle);
end;

function UIKitNativeIsValid(const AHandle: TUIKitNativeWindow): Boolean; inline;
begin
  Result := AHandle <> nil;
end;

end.
