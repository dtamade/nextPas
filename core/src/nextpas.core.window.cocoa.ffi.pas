unit nextpas.core.window.cocoa.ffi;

{** @desc Cocoa 窗口子集 ABI 声明层（window 家族）。
       只含窗口壳必需的 ObjC runtime + AppKit/Cocoa 类型与函数指针变量
       ——无逻辑、无 external；绑定真相归 window.cocoa.loader
       （经 nextpas.core.platform.dl）。

       由于 stage0 暂不支持 objectivec1 modeswitch，全部以纯 C 的
       objc_msgSend 家族 + dlopen 走运行时，避免链接期 ObjC 依赖。

       本单元禁止 uses 家族其他单元（INV-5）。 *}

{$I nextpas.core.settings.inc}

interface

type
  id = Pointer;
  SEL = Pointer;
  Class_ = Pointer;
  IMP = Pointer;
  BOOL = LongBool;

const
  NSWindowStyleMaskTitled          = 1 shl 0;
  NSWindowStyleMaskClosable        = 1 shl 1;
  NSWindowStyleMaskMiniaturizable  = 1 shl 2;
  NSWindowStyleMaskResizable       = 1 shl 3;

  NSBackingStoreBuffered           = 2;

  NSWindowCollectionBehaviorDefault = 0;

type
  NSRect = record origin_x, origin_y, size_w, size_h: Double; end;
  NSPoint = record x, y: Double; end;
  NSSize = record w, h: Double; end;

var
  // ObjC runtime
  objc_getClass: function(name: PAnsiChar): Class_; cdecl;
  sel_registerName: function(name: PAnsiChar): SEL; cdecl;
  objc_msgSend: function(self: id; op: SEL): id; cdecl; varargs;

  // libdispatch
  dispatch_get_main_queue: function: Pointer; cdecl;
  dispatch_async: procedure(queue: Pointer; block: Pointer); cdecl;
  dispatch_async_f: procedure(queue: Pointer; context: Pointer; work: Pointer); cdecl;

  // Minimal AppKit entry points resolved via dlsym on AppKit framework
  // We keep them as generic Pointer and call via objc_msgSend, so no direct ffi needed
  // Loader only probes presence of libobjc + libdispatch + AppKit

implementation

end.
