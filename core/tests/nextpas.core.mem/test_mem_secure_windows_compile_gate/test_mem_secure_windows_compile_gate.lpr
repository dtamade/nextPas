program test_mem_secure_windows_compile_gate;

{$I nextpas.core.settings.inc}

{$IFNDEF NEXTPAS_WINDOWS}
  {$fatal forced Windows compile gate must select NEXTPAS_WINDOWS}
{$ENDIF}

uses
  nextpas.core.platform.secure,
  nextpas.core.mem.secure;

var
  LByte: Byte;

begin
  LByte := $A5;
  platform_secure_zero(@LByte, SizeOf(LByte));
  LByte := $5A;
  SecureZeroMemory(@LByte, SizeOf(LByte));
end.
