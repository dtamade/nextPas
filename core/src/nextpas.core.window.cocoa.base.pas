unit nextpas.core.window.cocoa.base;

{** @desc Cocoa attach 基类型：按需存在的 NSWindow 句柄载体与零拷贝 inline 转换。
       非机械 4 件套占位：仅承载 NSWindow 句柄别名与 handle 互转，
       真实职责归本单元；通用窗口类型（TWindowOptions/TWindowEvent 等）仍归
       window.base 单源，避免薄 re-export 掩盖无真实职责的机械创建。 *}

{$I nextpas.core.settings.inc}
interface

uses
  nextpas.core.window.base;

type
  {** NSWindow* 句柄载体，生命周期归 AppKit，window 侧仅只读持有、Close 时置 nil 不释放。 *}
  TCocoaNativeWindow = type Pointer;

{** 零拷贝句柄互转：纯指针 cast，inline 零开销、无分配/无拷贝；
     复用 window.base 的 TWindowNativeHandle 单源定义，不引入 bytes.ops 重复拷贝。 *}
function CocoaNativeFromWindowHandle(const AHandle: TWindowNativeHandle): TCocoaNativeWindow; inline;
function WindowHandleFromCocoaNative(const AHandle: TCocoaNativeWindow): TWindowNativeHandle; inline;
function CocoaNativeIsValid(const AHandle: TCocoaNativeWindow): Boolean; inline;

implementation

function CocoaNativeFromWindowHandle(const AHandle: TWindowNativeHandle): TCocoaNativeWindow; inline;
begin
  Result := TCocoaNativeWindow(AHandle);
end;

function WindowHandleFromCocoaNative(const AHandle: TCocoaNativeWindow): TWindowNativeHandle; inline;
begin
  Result := TWindowNativeHandle(AHandle);
end;

function CocoaNativeIsValid(const AHandle: TCocoaNativeWindow): Boolean; inline;
begin
  Result := AHandle <> nil;
end;

end.
