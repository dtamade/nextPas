unit nextpas.core.window.android.ffi;

{** @desc Android surface attach 的 ABI 声明层。
       只含 ANativeWindow / AInputEvent 最小类型与函数指针变量
       ——无逻辑、无 external；绑定真相归 android.loader。

       本单元禁止 uses 家族其他单元（INV-5）。 *}

{$I nextpas.core.settings.inc}

interface

type
  PANativeWindow = Pointer;
  PAInputEvent = Pointer;

var
  ANativeWindow_getWidth: function(window: PANativeWindow): Int32; cdecl;
  ANativeWindow_getHeight: function(window: PANativeWindow): Int32; cdecl;
  ANativeWindow_setBuffersGeometry: function(window: PANativeWindow; width, height, format: Int32): Int32; cdecl;

implementation

end.
