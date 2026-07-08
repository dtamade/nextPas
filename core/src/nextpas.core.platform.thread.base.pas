unit nextpas.core.platform.thread.base;

{$I nextpas.core.settings.inc}

interface

type
  {** @desc 线程句柄（平台无关封装） *}
  TPlatformThreadHandle = Pointer;

  {** @desc 线程唯一标识符 *}
  TPlatformThreadToken = UInt64;

  {** @desc 线程入口函数类型（cdecl 调用约定） *}
  TPlatformThreadProc = function(AArg: Pointer): Pointer; cdecl;

  {** @desc 线程本地存储键 *}
  TPlatformTLSKey = PtrUInt;

implementation

end.
