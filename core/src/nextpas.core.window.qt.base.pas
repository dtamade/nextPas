unit nextpas.core.window.qt.base;

{** @desc Qt 基类型：按需存在的 QtWindow 句柄载体与零拷贝 inline 转换。
       非机械 4 件套占位：仅承载 QtWindow* 句柄别名与 handle 互转，
       真实职责归本单元；通用窗口类型（TWindowOptions/TWindowEvent 等）仍归
       window.base 单源，避免薄 re-export 掩盖无真实职责的机械创建。
       性能：句柄互转/判定 inline 零拷贝/零额外调用（纯指针 cast，O(1)均摊）；base 纯数据类型，零 L1 行为，守四件套 base←impl。
       稳定性：句柄生命周期归 shim（qt_window_destroy），window 侧只读持有、Close 置 nil 不释放，不丢资源。 *}

{$I nextpas.core.settings.inc}
interface

uses
  nextpas.core.window.base;

type
  {** QtWindow* 不透明句柄载体，生命周期归 shim，window 侧只读持有、Close 置 nil 不释放。 *}
  TQtNativeWindow = type Pointer;

{** 零拷贝句柄互转：纯指针 cast，inline 零开销、无分配/无拷贝；复用 window.base 单源句柄定义。 *}
function QtNativeFromWindowHandle(const AHandle: TWindowNativeHandle): TQtNativeWindow; inline;
function WindowHandleFromQtNative(const AHandle: TQtNativeWindow): TWindowNativeHandle; inline;
function QtNativeIsValid(const AHandle: TQtNativeWindow): Boolean; inline;

implementation

function QtNativeFromWindowHandle(const AHandle: TWindowNativeHandle): TQtNativeWindow; inline;
begin
  Result := TQtNativeWindow(AHandle);
end;

function WindowHandleFromQtNative(const AHandle: TQtNativeWindow): TWindowNativeHandle; inline;
begin
  Result := TWindowNativeHandle(AHandle);
end;

function QtNativeIsValid(const AHandle: TQtNativeWindow): Boolean; inline;
begin
  Result := AHandle <> nil;
end;

end.
