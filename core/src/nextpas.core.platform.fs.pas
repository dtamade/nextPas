unit nextpas.core.platform.fs;

{$I nextpas.core.settings.inc}

interface

function platform_fs_exists(const APath: PAnsiChar): Boolean;
function platform_fs_is_file(const APath: PAnsiChar): Boolean;
function platform_fs_is_dir(const APath: PAnsiChar): Boolean;
function platform_fs_file_size(const APath: PAnsiChar; out ASize: Int64): Int32;
function platform_fs_temp_dir(ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_fs_mktemp(const APrefix: PAnsiChar; const ASuffix: PAnsiChar;
  APathBuf: PAnsiChar; APathBufLen: Int32; out AFd: Int32): Int32;

implementation

uses
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.env,
  nextpas.core.platform.random;

function platform_fs_exists(const APath: PAnsiChar): Boolean;
var
  LStat: TPlatformFileStat;
begin
  Result := platform_file_stat(APath, LStat) = 0;
end;

function platform_fs_is_file(const APath: PAnsiChar): Boolean;
var
  LStat: TPlatformFileStat;
begin
  if platform_file_stat(APath, LStat) <> 0 then
    Exit(False);
  Result := LStat.FileType = ftRegular;
end;

function platform_fs_is_dir(const APath: PAnsiChar): Boolean;
var
  LStat: TPlatformFileStat;
begin
  if platform_file_stat(APath, LStat) <> 0 then
    Exit(False);
  Result := LStat.FileType = ftDirectory;
end;

function platform_fs_file_size(const APath: PAnsiChar; out ASize: Int64): Int32;
var
  LStat: TPlatformFileStat;
begin
  ASize := 0;
  Result := platform_file_stat(APath, LStat);
  if Result = 0 then
    ASize := LStat.Size;
end;

function platform_fs_temp_dir(ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen: Int32;
  LResult: Int32;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
{$IFDEF NEXTPAS_WINDOWS}
  LResult := platform_env_get('TEMP', ABuf, ABufLen, LLen);
  if LResult <> 0 then
    LResult := platform_env_get('TMP', ABuf, ABufLen, LLen);
  if LResult <> 0 then
  begin
    if ABufLen >= 4 then
    begin
      ABuf[0] := 'C'; ABuf[1] := ':'; ABuf[2] := '\';
      ABuf[3] := #0;
      Exit(3);
    end;
    Exit(-1);
  end;
  Result := LLen;
{$ELSE}
  LResult := platform_env_get('TMPDIR', ABuf, ABufLen, LLen);
  if LResult = 0 then
    Result := LLen
  else
  begin
    if ABufLen >= 5 then
    begin
      ABuf[0] := '/'; ABuf[1] := 't'; ABuf[2] := 'm'; ABuf[3] := 'p';
      ABuf[4] := #0;
      Result := 4;
    end
    else
      Result := -1;
  end;
{$ENDIF}
end;

function platform_fs_mktemp(const APrefix: PAnsiChar; const ASuffix: PAnsiChar;
  APathBuf: PAnsiChar; APathBufLen: Int32; out AFd: Int32): Int32;
const
  HEX_CHARS: array[0..15] of AnsiChar = '0123456789abcdef';
  MAX_ATTEMPTS = 16;
var
  LTmpDir: array[0..511] of AnsiChar;
  LTmpLen, LPrefixLen, LSuffixLen, LPos, I, LAttempt: Int32;
  LRandBytes: array[0..7] of Byte;
  LHandle: TPlatformFileHandle;
begin
  AFd := -1;
  if (APathBuf = nil) or (APathBufLen <= 0) then
    Exit(-1);

  LTmpLen := platform_fs_temp_dir(@LTmpDir[0], SizeOf(LTmpDir));
  if LTmpLen < 0 then
    Exit(-1);

  LPrefixLen := 0;
  if APrefix <> nil then
    while APrefix[LPrefixLen] <> #0 do Inc(LPrefixLen);

  LSuffixLen := 0;
  if ASuffix <> nil then
    while ASuffix[LSuffixLen] <> #0 do Inc(LSuffixLen);

  if LTmpLen + 1 + LPrefixLen + 16 + LSuffixLen + 1 > APathBufLen then
    Exit(-1);

  for LAttempt := 0 to MAX_ATTEMPTS - 1 do
  begin
    LPos := 0;
    Move(LTmpDir[0], APathBuf[0], LTmpLen);
    LPos := LTmpLen;
  {$IFDEF NEXTPAS_WINDOWS}
    if (LPos > 0) and (APathBuf[LPos-1] <> '\') then
    begin APathBuf[LPos] := '\'; Inc(LPos); end;
  {$ELSE}
    if (LPos > 0) and (APathBuf[LPos-1] <> '/') then
    begin APathBuf[LPos] := '/'; Inc(LPos); end;
  {$ENDIF}

    if LPrefixLen > 0 then
    begin
      Move(APrefix^, APathBuf[LPos], LPrefixLen);
      Inc(LPos, LPrefixLen);
    end;

    if platform_random_bytes(@LRandBytes[0], 8) <> 0 then
      Exit(-1);
    for I := 0 to 7 do
    begin
      APathBuf[LPos] := HEX_CHARS[(LRandBytes[I] shr 4) and $F];
      Inc(LPos);
      APathBuf[LPos] := HEX_CHARS[LRandBytes[I] and $F];
      Inc(LPos);
    end;

    if LSuffixLen > 0 then
    begin
      Move(ASuffix^, APathBuf[LPos], LSuffixLen);
      Inc(LPos, LSuffixLen);
    end;
    APathBuf[LPos] := #0;

    Result := platform_file_open(APathBuf, fomReadWrite, fcmCreateNew, LHandle);
    if Result = 0 then
    begin
    {$IFDEF NEXTPAS_WINDOWS}
      AFd := Int32(PtrUInt(LHandle.Value));
    {$ELSE}
      AFd := LHandle.Value;
    {$ENDIF}
      Exit(0);
    end;
  end;
  Result := -1;
end;

end.
