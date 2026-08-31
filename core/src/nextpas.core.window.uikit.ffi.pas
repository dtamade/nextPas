unit nextpas.core.window.uikit.ffi;

{** @desc UIKit attach 的 ABI 声明层。
       只含 UIWindow 最小类型与函数指针变量——无逻辑、无 external；
       绑定真相归 uikit.loader。

       本单元禁止 uses 家族其他单元（INV-5）。 *}

{$I nextpas.core.settings.inc}

interface

type
  PUIWindow = Pointer;

var
  UIWindow_getBounds: function(window: PUIWindow; outWidth, outHeight: PDouble): Int32; cdecl;

implementation

end.
