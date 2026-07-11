program test_platform_error_windows_compile_gate;

{$I nextpas.core.settings.inc}

{$IFNDEF NEXTPAS_WINDOWS}
  {$fatal Windows compile gate must select NEXTPAS_WINDOWS}
{$ENDIF}

uses
  nextpas.core.exception,
  nextpas.core.platform.error,
  nextpas.core.platform.windows.base;

var
  LErrorCode: DWORD;
  LCategory: TErrorCategory;

begin
  LErrorCode := ERROR_DISK_FULL;
  LCategory := platform_error_category(Int32(LErrorCode));
  if (LErrorCode <> DWORD(112)) or (LCategory <> ecResourceExhausted) then
    Halt(1);
end.
