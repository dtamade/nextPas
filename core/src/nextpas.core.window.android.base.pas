unit nextpas.core.window.android.base;

{** @desc Android attach 基类型：按需存在的 attach 句柄载体与零拷贝 inline 转换。
       非机械 4 件套占位：仅承载 ANativeWindow 句柄别名与 handle 互转，
       真实职责归本单元；通用窗口类型（TWindowOptions/TWindowEvent 等）仍归
       window.base 单源，避免薄 re-export 掩盖无真实职责的机械创建。
       性能：句柄互转/判定 inline 零拷贝/零额外调用（纯指针 cast，O(1)均摊）；base 纯数据类型，零 L1 行为，守四件套 base←impl。
       稳定性：句柄生命周期归宿主 Activity（ANativeWindow），window 侧只读持有、Close 置 nil 不释放，不丢资源。 *}

{$I nextpas.core.settings.inc}
interface

uses
  nextpas.core.window.base;

type
  {** ANativeWindow 句柄载体，生命周期归宿主 Activity，window 侧仅只读持有、Close 时置 nil 不释放。 *}
  TAndroidNativeWindow = type Pointer;

const
  ANDROID_WINDOW_FORMAT_RGBA8888 = 1;
  ANDROID_WINDOW_FORMAT_RGB565   = 4;

{** 零拷贝句柄互转：纯指针 cast，inline 零开销、无分配/无拷贝；
     复用 window.base 的 TWindowNativeHandle 单源定义，不引入 bytes.ops 重复拷贝。 *}
function AndroidNativeFromWindowHandle(const AHandle: TWindowNativeHandle): TAndroidNativeWindow; inline;
function WindowHandleFromAndroidNative(const AHandle: TAndroidNativeWindow): TWindowNativeHandle; inline;
function AndroidNativeIsValid(const AHandle: TAndroidNativeWindow): Boolean; inline;

implementation

function AndroidNativeFromWindowHandle(const AHandle: TWindowNativeHandle): TAndroidNativeWindow; inline;
begin
  Result := TAndroidNativeWindow(AHandle);
end;

function WindowHandleFromAndroidNative(const AHandle: TAndroidNativeWindow): TWindowNativeHandle; inline;
begin
  Result := TWindowNativeHandle(AHandle);
end;

function AndroidNativeIsValid(const AHandle: TAndroidNativeWindow): Boolean; inline;
begin
  Result := AHandle <> nil;
end;

end.
