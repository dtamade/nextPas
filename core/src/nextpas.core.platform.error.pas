unit nextpas.core.platform.error;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

{ Portable platform error codes — canonical definitions }
const
  PLATFORM_ERR_AGAIN       = 11;    { Resource temporarily unavailable }
  PLATFORM_ERR_BUSY        = 16;    { Device or resource busy }
  PLATFORM_ERR_INVALID     = 22;    { Invalid argument }
  PLATFORM_ERR_UNSUPPORTED = 95;    { Operation not supported }
  PLATFORM_ERR_TIMEOUT     = 110;   { Operation timed out }

function platform_error_message(ACode: Int32; ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_error_category(ACode: Int32): TErrorCategory;
procedure platform_fatal(const AMsg: PAnsiChar);
procedure platform_fatal_code(const AMsg: PAnsiChar; ACode: Int32);

implementation

uses
{$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi
  {$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
  {$ELSEIF defined(NEXTPAS_MACOS)}
  , nextpas.core.platform.darwin.base
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  , nextpas.core.platform.freebsd.base
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  , nextpas.core.platform.android.base
  {$ELSE}
  , nextpas.core.platform.unix.base
  {$ENDIF}
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi
{$ENDIF}
{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
  SysUtils
{$ENDIF}
  ;

function CopyPlatformErrorMessage(const AMessage: PAnsiChar; ABuf: PAnsiChar;
  ABufLen: Int32): Int32;
var
  LLen: Int32;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);

  LLen := 0;
  while AMessage[LLen] <> #0 do
    Inc(LLen);
  if LLen >= ABufLen then
    LLen := ABufLen - 1;
  if LLen > 0 then
    Move(AMessage^, ABuf^, LLen);
  ABuf[LLen] := #0;
  Result := LLen;
end;

function TryPlatformErrorTokenMessage(ACode: Int32; ABuf: PAnsiChar;
  ABufLen: Int32; out ALen: Int32): Boolean;
begin
  Result := True;
  case ACode of
    PLATFORM_ERR_INVALID:
      ALen := CopyPlatformErrorMessage('invalid', ABuf, ABufLen);
    PLATFORM_ERR_UNSUPPORTED:
      ALen := CopyPlatformErrorMessage('unsupported', ABuf, ABufLen);
    PLATFORM_ERR_TIMEOUT:
      ALen := CopyPlatformErrorMessage('timeout', ABuf, ABufLen);
    PLATFORM_ERR_AGAIN:
      ALen := CopyPlatformErrorMessage('again', ABuf, ABufLen);
    PLATFORM_ERR_BUSY:
      ALen := CopyPlatformErrorMessage('busy', ABuf, ABufLen);
  else
    Result := False;
    ALen := -1;
  end;
end;

{$IFDEF NEXTPAS_UNIX}
function platform_error_message(ACode: Int32; ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LMsg: PAnsiChar;
  LLen, I: Int32;
begin
  if TryPlatformErrorTokenMessage(ACode, ABuf, ABufLen, Result) then
    Exit;
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
function platform_error_message(ACode: Int32; ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen: DWORD;
  I: Int32;
begin
  if TryPlatformErrorTokenMessage(ACode, ABuf, ABufLen, Result) then
    Exit;
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
  if TryPlatformErrorTokenMessage(ACode, ABuf, ABufLen, Result) then
    Exit;
  if ABuf <> nil then ABuf[0] := #0;
  Result := -1;
end;
{$ENDIF}

function platform_error_category(ACode: Int32): TErrorCategory;
begin
  case ACode of
    0:
      Result := ecNone;
    {$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
    ESysENOENT:
      Result := ecNotFound;
    ESysEPERM,
    ESysEACCES:
      Result := ecPermission;
    ESysEEXIST:
      Result := ecAlreadyExists;
    ESysEADDRINUSE:
      Result := ecAlreadyExists;
    ESysENETUNREACH,
    ESysEHOSTUNREACH,
    ESysENOTCONN:
      Result := ecNetwork;
    ESysENOMEM,
    ESysENOSPC:
      Result := ecResourceExhausted;
    ESysEINVAL:
      Result := ecInvalidArgument;
    ESysEOPNOTSUPP:
      Result := ecNotSupported;
    ESysETIMEDOUT:
      Result := ecTimeout;
    ESysEAGAIN,
    ESysEBUSY:
      Result := ecWouldBlock;
    ESysEIO:
      Result := ecIO;
    ESysEPIPE,
    ESysECONNABORTED,
    ESysECONNRESET,
    ESysECONNREFUSED:
      Result := ecIO;
    ESysEINTR:
      Result := ecInterrupted;
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    ERROR_FILE_NOT_FOUND,
    ERROR_PATH_NOT_FOUND,
    ERROR_MOD_NOT_FOUND,
    ERROR_PROC_NOT_FOUND,
    ERROR_ENVVAR_NOT_FOUND,
    ERROR_NOT_FOUND,
    WSAHOST_NOT_FOUND:
      Result := ecNotFound;
    ERROR_ACCESS_DENIED:
      Result := ecPermission;
    ERROR_FILE_EXISTS,
    ERROR_ALREADY_EXISTS,
    WSAEADDRINUSE:
      Result := ecAlreadyExists;
    WSAENETUNREACH,
    WSAEHOSTUNREACH,
    WSAENOTCONN:
      Result := ecNetwork;
    ERROR_NOT_ENOUGH_MEMORY,
    ERROR_OUTOFMEMORY,
    WSAENOBUFS:
      Result := ecResourceExhausted;
    ERROR_INVALID_PARAMETER:
      Result := ecInvalidArgument;
    ERROR_NOT_SUPPORTED:
      Result := ecNotSupported;
    ERROR_TIMEOUT,
    WSAETIMEDOUT:
      Result := ecTimeout;
    WSAEWOULDBLOCK:
      Result := ecWouldBlock;
    ERROR_BROKEN_PIPE,
    WSAECONNABORTED,
    WSAECONNRESET,
    WSAECONNREFUSED:
      Result := ecIO;
    ERROR_OPERATION_ABORTED:
      Result := ecInterrupted;
    {$ENDIF}
    PLATFORM_ERR_INVALID:
      Result := ecInvalidArgument;
    PLATFORM_ERR_UNSUPPORTED:
      Result := ecNotSupported;
    PLATFORM_ERR_TIMEOUT:
      Result := ecTimeout;
    PLATFORM_ERR_AGAIN,
    PLATFORM_ERR_BUSY:
      Result := ecWouldBlock;
  else
    Result := ecInternal;
  end;
end;

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
