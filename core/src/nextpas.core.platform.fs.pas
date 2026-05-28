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
function platform_fs_mkdir_p(const APath: PAnsiChar; AMode: UInt32): Int32;
function platform_fs_copy_file(const ASrc: PAnsiChar; const ADst: PAnsiChar): Int32;
function platform_fs_write_atomic(const APath: PAnsiChar;
  AData: Pointer; ALen: PtrUInt): Int32;

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

function platform_fs_mkdir_p(const APath: PAnsiChar; AMode: UInt32): Int32;
var
  LBuf: array[0..1023] of AnsiChar;
  LLen, I: Int32;
  LR: Int32;
begin
  if (APath = nil) or (APath[0] = #0) then
    Exit(-1);
  LLen := 0;
  while (LLen < 1023) and (APath[LLen] <> #0) do
  begin
    LBuf[LLen] := APath[LLen];
    Inc(LLen);
  end;
  LBuf[LLen] := #0;

  I := 1;
  while I <= LLen do
  begin
  {$IFDEF NEXTPAS_WINDOWS}
    if (LBuf[I] = '\') or (LBuf[I] = '/') or (I = LLen) then
  {$ELSE}
    if (LBuf[I] = '/') or (I = LLen) then
  {$ENDIF}
    begin
      if I = LLen then
      begin
        LR := platform_file_mkdir(@LBuf[0], AMode);
        if (LR <> 0) and platform_fs_is_dir(@LBuf[0]) then
          LR := 0;
        if LR <> 0 then Exit(LR);
      end
      else
      begin
        LBuf[I] := #0;
        LR := platform_file_mkdir(@LBuf[0], AMode);
        if (LR <> 0) and (not platform_fs_is_dir(@LBuf[0])) then
          Exit(LR);
      {$IFDEF NEXTPAS_WINDOWS}
        LBuf[I] := '\';
      {$ELSE}
        LBuf[I] := '/';
      {$ENDIF}
      end;
    end;
    Inc(I);
  end;
  Result := 0;
end;

function platform_fs_copy_file(const ASrc: PAnsiChar; const ADst: PAnsiChar): Int32;
var
  LSrcH, LDstH: TPlatformFileHandle;
  LBuf: array[0..8191] of Byte;
  LRead, LWritten: PtrUInt;
  LR: Int32;
begin
  LR := platform_file_open(ASrc, fomReadOnly, fcmOpenExisting, LSrcH);
  if LR <> 0 then Exit(LR);
  LR := platform_file_open(ADst, fomWriteOnly, fcmCreateAlways, LDstH);
  if LR <> 0 then
  begin
    platform_file_close(LSrcH);
    Exit(LR);
  end;
  repeat
    LR := platform_file_read(LSrcH, @LBuf[0], SizeOf(LBuf), LRead);
    if (LR <> 0) or (LRead = 0) then Break;
    LR := platform_file_write(LDstH, @LBuf[0], LRead, LWritten);
  until (LR <> 0) or (LWritten < LRead);
  platform_file_close(LDstH);
  platform_file_close(LSrcH);
  Result := LR;
end;

function platform_fs_write_atomic(const APath: PAnsiChar;
  AData: Pointer; ALen: PtrUInt): Int32;
var
  LTmpPath: array[0..1023] of AnsiChar;
  LPathLen, I: Int32;
  LH: TPlatformFileHandle;
  LWritten: PtrUInt;
  LR: Int32;
  LFd: Int32;
begin
  if (APath = nil) or (APath[0] = #0) then
    Exit(-1);
  LPathLen := 0;
  while (LPathLen < 1000) and (APath[LPathLen] <> #0) do
  begin
    LTmpPath[LPathLen] := APath[LPathLen];
    Inc(LPathLen);
  end;
  LTmpPath[LPathLen] := '.'; Inc(LPathLen);
  LTmpPath[LPathLen] := 't'; Inc(LPathLen);
  LTmpPath[LPathLen] := 'm'; Inc(LPathLen);
  LTmpPath[LPathLen] := 'p'; Inc(LPathLen);
  LTmpPath[LPathLen] := #0;

  LR := platform_file_open(@LTmpPath[0], fomWriteOnly, fcmCreateAlways, LH);
  if LR <> 0 then Exit(LR);

  if ALen > 0 then
  begin
    LR := platform_file_write(LH, AData, ALen, LWritten);
    if (LR <> 0) or (LWritten <> ALen) then
    begin
      platform_file_close(LH);
      platform_file_unlink(@LTmpPath[0]);
      Exit(LR);
    end;
  end;

  platform_file_sync(LH);
  platform_file_close(LH);

  LR := platform_file_rename(@LTmpPath[0], APath);
  if LR <> 0 then
    platform_file_unlink(@LTmpPath[0]);
  Result := LR;
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
