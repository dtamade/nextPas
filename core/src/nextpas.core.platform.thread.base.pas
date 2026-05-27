unit nextpas.core.platform.thread.base;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformThreadHandle = Pointer;
  TPlatformThreadToken = UInt64;
  TPlatformThreadProc = function(AArg: Pointer): Pointer; cdecl;
  TPlatformTLSKey = PtrUInt;

implementation

end.
