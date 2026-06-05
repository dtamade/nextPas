unit nextpas.core.platform.windows.utf16;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.windows.base;

function platform_windows_utf8_to_wide(const AText: PAnsiChar): UnicodeString;
function platform_windows_utf8_to_wide_checked(const AText: PAnsiChar;
  out AWide: UnicodeString): Boolean;
function platform_windows_wide_to_utf8(const AText: PWideChar): AnsiString;
function platform_windows_wide_to_utf8_checked(const AText: PWideChar;
  out AUtf8: AnsiString): Boolean;
function platform_windows_copy_utf8_to_buffer(const AText: AnsiString;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_windows_wide_to_utf8_buffer(const AText: PWideChar;
  ABuf: PAnsiChar; ABufLen: Int32; out ALen: Int32): Boolean;
function platform_windows_envp_to_wide_block(const AEnvp: PPAnsiChar;
  out ABlock: UnicodeString): Boolean;
function platform_windows_argv_to_command_line(const APath: PAnsiChar;
  AArgv: PPAnsiChar; out ACmd: UnicodeString): Boolean;

implementation

uses
  nextpas.core.platform.windows.ffi;

function AnsiZLen(const AText: PAnsiChar): Int32;
begin
  Result := 0;
  if AText = nil then
    Exit;
  while AText[Result] <> #0 do
    Inc(Result);
end;

function WideZLen(const AText: PWideChar): Int32;
begin
  Result := 0;
  if AText = nil then
    Exit;
  while AText[Result] <> #0 do
    Inc(Result);
end;

function platform_windows_utf8_to_wide(const AText: PAnsiChar): UnicodeString;
begin
  if not platform_windows_utf8_to_wide_checked(AText, Result) then
    Result := '';
end;

function platform_windows_utf8_to_wide_checked(const AText: PAnsiChar;
  out AWide: UnicodeString): Boolean;
var
  LInputLen: Int32;
  LWideLen: Int32;
begin
  AWide := '';
  LInputLen := AnsiZLen(AText);
  if LInputLen = 0 then
    Exit(True);

  LWideLen := MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
    AText, LInputLen, nil, 0);
  if LWideLen <= 0 then
    Exit(False);

  SetLength(AWide, LWideLen);
  Result := MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
    AText, LInputLen, PWideChar(AWide), LWideLen) = LWideLen;
  if not Result then
    AWide := '';
end;

function platform_windows_wide_to_utf8(const AText: PWideChar): AnsiString;
begin
  if not platform_windows_wide_to_utf8_checked(AText, Result) then
    Result := '';
end;

function platform_windows_wide_to_utf8_checked(const AText: PWideChar;
  out AUtf8: AnsiString): Boolean;
var
  LInputLen: Int32;
  LUtf8Len: Int32;
begin
  AUtf8 := '';
  LInputLen := WideZLen(AText);
  if LInputLen = 0 then
    Exit(True);

  LUtf8Len := WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
    AText, LInputLen, nil, 0, nil, nil);
  if LUtf8Len <= 0 then
    Exit(False);

  SetLength(AUtf8, LUtf8Len);
  Result := WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
    AText, LInputLen, PAnsiChar(AUtf8), LUtf8Len, nil, nil) = LUtf8Len;
  if not Result then
    AUtf8 := '';
end;

function platform_windows_copy_utf8_to_buffer(const AText: AnsiString;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LCopyLen: Int32;
begin
  Result := Length(AText);
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit;

  LCopyLen := Result;
  if LCopyLen >= ABufLen then
    LCopyLen := ABufLen - 1;
  if LCopyLen > 0 then
    Move(AText[1], ABuf^, LCopyLen);
  ABuf[LCopyLen] := #0;
end;

function platform_windows_wide_to_utf8_buffer(const AText: PWideChar;
  ABuf: PAnsiChar; ABufLen: Int32; out ALen: Int32): Boolean;
var
  LUtf8: AnsiString;
begin
  Result := platform_windows_wide_to_utf8_checked(AText, LUtf8);
  if not Result then
  begin
    ALen := 0;
    Exit;
  end;
  ALen := platform_windows_copy_utf8_to_buffer(LUtf8, ABuf, ABufLen);
end;

function platform_windows_envp_to_wide_block(const AEnvp: PPAnsiChar;
  out ABlock: UnicodeString): Boolean;
var
  LEntry: UnicodeString;
  LP: PPAnsiChar;
begin
  ABlock := '';
  if AEnvp = nil then
    Exit(True);

  LP := AEnvp;
  while LP^ <> nil do
  begin
    if not platform_windows_utf8_to_wide_checked(LP^, LEntry) then
    begin
      ABlock := '';
      Exit(False);
    end;
    ABlock := ABlock + LEntry + WideChar(#0);
    Inc(LP);
  end;
  ABlock := ABlock + WideChar(#0);
  Result := True;
end;

function ArgNeedsQuoting(const AArg: UnicodeString): Boolean;
var
  I: Int32;
begin
  if AArg = '' then
    Exit(True);
  for I := 1 to Length(AArg) do
    if (AArg[I] = WideChar(' ')) or (AArg[I] = WideChar(#9)) or
       (AArg[I] = WideChar('"')) then
      Exit(True);
  Result := False;
end;

procedure AppendRepeated(var AText: UnicodeString; AChar: WideChar;
  ACount: Int32);
begin
  while ACount > 0 do
  begin
    AText := AText + AChar;
    Dec(ACount);
  end;
end;

function QuoteWindowsArg(const AArg: UnicodeString): UnicodeString;
var
  I: Int32;
  LBackslashes: Int32;
begin
  if not ArgNeedsQuoting(AArg) then
    Exit(AArg);

  Result := WideChar('"');
  LBackslashes := 0;
  for I := 1 to Length(AArg) do
  begin
    if AArg[I] = WideChar('\') then
    begin
      Inc(LBackslashes);
      Continue;
    end;

    if AArg[I] = WideChar('"') then
    begin
      AppendRepeated(Result, WideChar('\'), LBackslashes * 2 + 1);
      Result := Result + WideChar('"');
      LBackslashes := 0;
      Continue;
    end;

    AppendRepeated(Result, WideChar('\'), LBackslashes);
    LBackslashes := 0;
    Result := Result + AArg[I];
  end;
  AppendRepeated(Result, WideChar('\'), LBackslashes * 2);
  Result := Result + WideChar('"');
end;

function platform_windows_argv_to_command_line(const APath: PAnsiChar;
  AArgv: PPAnsiChar; out ACmd: UnicodeString): Boolean;
var
  LArg: UnicodeString;
  LP: PPAnsiChar;
begin
  ACmd := '';
  if not platform_windows_utf8_to_wide_checked(APath, LArg) then
    Exit(False);
  if LArg = '' then
    Exit(False);

  ACmd := QuoteWindowsArg(LArg);
  if AArgv = nil then
    Exit(True);

  LP := AArgv;
  Inc(LP);
  while LP^ <> nil do
  begin
    if not platform_windows_utf8_to_wide_checked(LP^, LArg) then
    begin
      ACmd := '';
      Exit(False);
    end;
    ACmd := ACmd + WideChar(' ') + QuoteWindowsArg(LArg);
    Inc(LP);
  end;
  Result := True;
end;

end.
