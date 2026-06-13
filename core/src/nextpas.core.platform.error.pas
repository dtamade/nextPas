unit nextpas.core.platform.error;

{$I nextpas.core.settings.inc}

interface

{ Portable platform error codes — canonical definitions }
const
  PLATFORM_ERR_AGAIN       = 11;    { Resource temporarily unavailable }
  PLATFORM_ERR_BUSY        = 16;    { Device or resource busy }
  PLATFORM_ERR_INVALID     = 22;    { Invalid argument }
  PLATFORM_ERR_UNSUPPORTED = 95;    { Operation not supported }
  PLATFORM_ERR_TIMEOUT     = 110;   { Operation timed out }

function platform_error_message(ACode: Int32; ABuf: PAnsiChar; ABufLen: Int32): Int32;
procedure platform_fatal(const AMsg: PAnsiChar);
procedure platform_fatal_code(const AMsg: PAnsiChar; ACode: Int32);

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

procedure WriteStderr(const S: PAnsiChar; ALen: Int32);
var
  LWritten: DWORD;
begin
{$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.ffi.write(2, S, ALen);
{$ELSE}
  if ALen > 0 then
    WriteFile(GetStdHandle(STD_ERROR_HANDLE), S, ALen, @LWritten, nil);
{$ENDIF}
end;

procedure platform_fatal(const AMsg: PAnsiChar);
var
  LLen: Int32;
begin
  WriteStderr('fatal: ', 7);
  if AMsg <> nil then
  begin
    LLen := 0;
    while AMsg[LLen] <> #0 do Inc(LLen);
    if LLen > 0 then
      WriteStderr(AMsg, LLen);
  end;
  WriteStderr(PAnsiChar(#10), 1);
  System.Halt(1);
end;

procedure platform_fatal_code(const AMsg: PAnsiChar; ACode: Int32);
var
  LLen: Int32;
  LBuf: array[0..15] of AnsiChar;
  LCodeLen, I: Int32;
  LVal: UInt32;
begin
  WriteStderr('fatal: ', 7);
  if AMsg <> nil then
  begin
    LLen := 0;
    while AMsg[LLen] <> #0 do Inc(LLen);
    if LLen > 0 then
      WriteStderr(AMsg, LLen);
  end;
  WriteStderr(' (code ', 7);
  if ACode < 0 then
  begin
    WriteStderr('-', 1);
    LVal := UInt32(-ACode);
  end
  else
    LVal := UInt32(ACode);
  LCodeLen := 0;
  repeat
    LBuf[LCodeLen] := AnsiChar(Ord('0') + (LVal mod 10));
    LVal := LVal div 10;
    Inc(LCodeLen);
  until LVal = 0;
  // reverse
  for I := 0 to (LCodeLen div 2) - 1 do
  begin
    LBuf[15] := LBuf[I];
    LBuf[I] := LBuf[LCodeLen - 1 - I];
    LBuf[LCodeLen - 1 - I] := LBuf[15];
  end;
  WriteStderr(@LBuf[0], LCodeLen);
  WriteStderr(')'#10, 2);
  System.Halt(ACode and $FF);
end;

end.
