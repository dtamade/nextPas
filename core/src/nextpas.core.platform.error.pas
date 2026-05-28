unit nextpas.core.platform.error;

{$I nextpas.core.settings.inc}

interface

function platform_error_message(ACode: Int32; ABuf: PAnsiChar; ABufLen: Int32): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

function platform_error_message(ACode: Int32; ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LMsg: PAnsiChar;
  LLen, I: Int32;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  LMsg := strerror(ACode);
  if LMsg = nil then
  begin
    ABuf[0] := #0;
    Exit(-1);
  end;
  LLen := 0;
  while LMsg[LLen] <> #0 do
    Inc(LLen);
  if LLen >= ABufLen then
    LLen := ABufLen - 1;
  for I := 0 to LLen - 1 do
    ABuf[I] := LMsg[I];
  ABuf[LLen] := #0;
  Result := LLen;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

function platform_error_message(ACode: Int32; ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen: DWORD;
  I: Int32;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  LLen := FormatMessageA(
    FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS,
    nil, DWORD(ACode), 0, ABuf, DWORD(ABufLen), nil);
  if LLen = 0 then
  begin
    ABuf[0] := #0;
    Exit(-1);
  end;
  // Strip trailing \r\n
  I := Int32(LLen);
  while (I > 0) and ((ABuf[I-1] = #13) or (ABuf[I-1] = #10)) do
    Dec(I);
  ABuf[I] := #0;
  Result := I;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_error_message(ACode: Int32; ABuf: PAnsiChar; ABufLen: Int32): Int32;
begin
  if ABuf <> nil then ABuf[0] := #0;
  Result := -1;
end;
{$ENDIF}

end.
