{ nextpas.core.webview.webview2.ole32.inc — platform branching via .inc single source, owner platform.windows.base
  CoTaskMemFree: Windows external 'ole32.dll', Linux inline no-op stub, zero extra call, releases not lost via caller nil guard }
{$IFDEF MSWINDOWS}
procedure CoTaskMemFree(pv: Pointer); stdcall; external 'ole32.dll' name 'CoTaskMemFree';
{$ELSE}
procedure CoTaskMemFree(pv: Pointer); inline;
begin
end;
{$ENDIF}
