unit nextpas.core.platform.fs;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.files.base;

type
  TPlatformWalkAction = (
    pwaContinue,
    pwaSkipSubtree,
    pwaStop
  );

  TPlatformWalkEntry = record
    Path: PAnsiChar;
    PathLen: Int32;
    Name: PAnsiChar;
    NameLen: Int32;
    FileType: TPlatformFileType;
    Depth: Int32;
    ErrorCode: Int32;
  end;

  TPlatformWalkCallback = function(const AEntry: TPlatformWalkEntry;
    AUserData: Pointer): TPlatformWalkAction;

const
  PLATFORM_WALK_COMPLETED = 0;
  PLATFORM_WALK_STOPPED   = 1;
  PLATFORM_WALK_BADARGS   = -1;
  PLATFORM_WALK_MAX_DEPTH = 256;
  PLATFORM_FS_SHORT_WRITE_ERROR = -5;
  PLATFORM_FS_SHORT_READ_ERROR = -6;

function platform_fs_exists(const APath: PAnsiChar): Boolean;
function platform_fs_is_file(const APath: PAnsiChar): Boolean;
function platform_fs_is_dir(const APath: PAnsiChar): Boolean;
function platform_fs_is_executable(const APath: PAnsiChar): Boolean;
function platform_fs_file_size(const APath: PAnsiChar; out ASize: Int64): Int32;
function platform_fs_temp_dir(ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_fs_mktemp(const APrefix: PAnsiChar; const ASuffix: PAnsiChar;
  APathBuf: PAnsiChar; APathBufLen: Int32; out AFd: Int32): Int32;
function platform_fs_mktemp_handle(const APrefix: PAnsiChar; const ASuffix: PAnsiChar;
  APathBuf: PAnsiChar; APathBufLen: Int32; out AHandle: TPlatformFileHandle): Int32;
function platform_fs_mkdir_p(const APath: PAnsiChar; AMode: UInt32): Int32;
function platform_fs_copy_file(const ASrc: PAnsiChar; const ADst: PAnsiChar): Int32;
function platform_fs_write_atomic(const APath: PAnsiChar;
  AData: Pointer; ALen: PtrUInt): Int32;
function platform_fs_read_file(const APath: PAnsiChar;
  out AData: Pointer; out ALen: PtrUInt): Int32;
function platform_fs_read_file_into(const APath: PAnsiChar;
  ABuf: Pointer; ABufCapacity: PtrUInt; out ALen: PtrUInt): Int32;
procedure platform_fs_free_buf(AData: Pointer);
function platform_fs_walk(const ARoot: PAnsiChar;
  ACallback: TPlatformWalkCallback; AUserData: Pointer;
  AFollowSymlinks: Boolean): Int32;

implementation

uses
  nextpas.core.platform.files,
  nextpas.core.platform.env,
  nextpas.core.platform.random
{$IFDEF NEXTPAS_UNIX}
  , nextpas.core.platform.posix.ffi
{$ENDIF}
  ;

const
  PLATFORM_FS_COPY_BUFFER_SIZE = 65536;
  PLATFORM_FS_PATH_BUF_SIZE = 4096;
  PLATFORM_FS_MKTEMP_PATH_BUF_SIZE = 1024;
  PLATFORM_FS_TEMP_DIR_BUF_SIZE = 512;

function platform_fs_write_all(const AHandle: TPlatformFileHandle;
  AData: Pointer; ALen: PtrUInt): Int32;
var
  LTotal, LWritten: PtrUInt;
begin
  LTotal := 0;
  while LTotal < ALen do
  begin
    Result := platform_file_write(AHandle,
      Pointer(PtrUInt(AData) + LTotal), ALen - LTotal, LWritten);
    if Result <> 0 then
      Exit;
    if LWritten = 0 then
      Exit(PLATFORM_FS_SHORT_WRITE_ERROR);
    Inc(LTotal, LWritten);
  end;
  Result := 0;
end;

function platform_fs_read_all(const AHandle: TPlatformFileHandle;
  AData: Pointer; ALen: PtrUInt; out ABytesRead: PtrUInt): Int32;
var
  LChunk: PtrUInt;
begin
  ABytesRead := 0;
  while ABytesRead < ALen do
  begin
    Result := platform_file_read(AHandle,
      Pointer(PtrUInt(AData) + ABytesRead), ALen - ABytesRead, LChunk);
    if Result <> 0 then
      Exit;
    if LChunk = 0 then
      Exit(PLATFORM_FS_SHORT_READ_ERROR);
    Inc(ABytesRead, LChunk);
  end;
  Result := 0;
end;

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

function platform_fs_is_executable(const APath: PAnsiChar): Boolean;
begin
{$IFDEF NEXTPAS_UNIX}
  Result := access(APath, 1{X_OK}) = 0;
{$ELSEIF defined(NEXTPAS_WINDOWS)}
  Result := platform_fs_is_file(APath);
{$ELSE}
  Result := False;
{$ENDIF}
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
  LBuf: array[0..PLATFORM_FS_PATH_BUF_SIZE - 1] of AnsiChar;
  LLen, I: Int32;
  LR: Int32;
begin
  if (APath = nil) or (APath[0] = #0) then
    Exit(-1);
  LLen := 0;
  while (LLen < PLATFORM_FS_PATH_BUF_SIZE - 1) and (APath[LLen] <> #0) do
  begin
    LBuf[LLen] := APath[LLen];
    Inc(LLen);
  end;
  LBuf[LLen] := #0;
  if LLen >= PLATFORM_FS_PATH_BUF_SIZE - 1 then Exit(-36); { ENAMETOOLONG }

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
        begin
          if LR = 17{EEXIST} then
            Exit(20{ENOTDIR});  { path component is not a directory }
          Exit(LR);
        end;
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
  LBuf: array[0..PLATFORM_FS_COPY_BUFFER_SIZE - 1] of Byte;
  LRead: PtrUInt;
  LR, LCloseR: Int32;
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
    LR := platform_fs_write_all(LDstH, @LBuf[0], LRead);
  until LR <> 0;
  LCloseR := platform_file_close(LDstH);
  if (LR = 0) and (LCloseR <> 0) then
    LR := LCloseR;
  LCloseR := platform_file_close(LSrcH);
  if (LR = 0) and (LCloseR <> 0) then
    LR := LCloseR;
  Result := LR;
end;

function platform_fs_write_atomic(const APath: PAnsiChar;
  AData: Pointer; ALen: PtrUInt): Int32;
const
  HEX: array[0..15] of AnsiChar = '0123456789abcdef';
  MAX_ATOMIC_TEMP_ATTEMPTS = 16;
var
  LTmpPath: array[0..PLATFORM_FS_MKTEMP_PATH_BUF_SIZE - 1] of AnsiChar;
  LBaseLen, LPathLen, I, LAttempt: Int32;
  LH: TPlatformFileHandle;
  LR: Int32;
  LRand: array[0..5] of Byte;
begin
  if (APath = nil) or (APath[0] = #0) then
    Exit(-1);
  LBaseLen := 0;
  { Invariant: 1024 buffer - 1(dot) - 12(hex) - 1(NUL) = 1010 max base path }
  while (LBaseLen < 1010) and (APath[LBaseLen] <> #0) do
  begin
    LTmpPath[LBaseLen] := APath[LBaseLen];
    Inc(LBaseLen);
  end;
  LR := -1;
  for LAttempt := 0 to MAX_ATOMIC_TEMP_ATTEMPTS - 1 do
  begin
    LPathLen := LBaseLen;
    LTmpPath[LPathLen] := '.'; Inc(LPathLen);
    if platform_random_bytes(@LRand[0], 6) <> 0 then
      Exit(-1);
    for I := 0 to 5 do
    begin
      LTmpPath[LPathLen] := HEX[LRand[I] shr 4]; Inc(LPathLen);
      LTmpPath[LPathLen] := HEX[LRand[I] and $0F]; Inc(LPathLen);
    end;
    LTmpPath[LPathLen] := #0;

    LR := platform_file_open(@LTmpPath[0], fomWriteOnly, fcmCreateNew, LH);
    if LR = 0 then
      Break;
  end;
  if LR <> 0 then Exit(LR);

  if ALen > 0 then
  begin
    LR := platform_fs_write_all(LH, AData, ALen);
    if LR <> 0 then
    begin
      platform_file_close(LH);
      platform_file_unlink(@LTmpPath[0]);
      Exit(LR);
    end;
  end;

  LR := platform_file_sync(LH);
  if LR <> 0 then
  begin
    platform_file_close(LH);
    platform_file_unlink(@LTmpPath[0]);
    Exit(LR);
  end;

  LR := platform_file_close(LH);
  if LR <> 0 then
  begin
    platform_file_unlink(@LTmpPath[0]);
    Exit(LR);
  end;

  LR := platform_file_rename(@LTmpPath[0], APath);
  if LR <> 0 then
    platform_file_unlink(@LTmpPath[0]);
  Result := LR;
end;

function platform_fs_mktemp_impl(APathBuf: PAnsiChar; APathBufLen: Int32;
  const APrefix, ASuffix: PAnsiChar; out AHandle: TPlatformFileHandle): Int32;
const
  HEX_CHARS: array[0..15] of AnsiChar = '0123456789abcdef';
  MAX_ATTEMPTS = 16;
var
  LTmpDir: array[0..PLATFORM_FS_TEMP_DIR_BUF_SIZE - 1] of AnsiChar;
  LTmpLen, LPrefixLen, LSuffixLen, LPos, I, LAttempt: Int32;
  LRandBytes: array[0..7] of Byte;
begin
  AHandle := PLATFORM_FILE_INVALID_HANDLE;
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

    Result := platform_file_open(APathBuf, fomReadWrite, fcmCreateNew, AHandle);
    if Result = 0 then
      Exit(0);
  end;
  Result := -1;
end;

function platform_fs_mktemp(const APrefix: PAnsiChar; const ASuffix: PAnsiChar;
  APathBuf: PAnsiChar; APathBufLen: Int32; out AFd: Int32): Int32;
var
  LHandle: TPlatformFileHandle;
begin
  AFd := -1;
  Result := platform_fs_mktemp_impl(APathBuf, APathBufLen, APrefix, ASuffix, LHandle);
  if Result = 0 then
  begin
  {$IFDEF NEXTPAS_WINDOWS}
    AFd := Int32(PtrUInt(LHandle.Value));
  {$ELSE}
    AFd := LHandle.Value;
  {$ENDIF}
  end;
end;

function platform_fs_mktemp_handle(const APrefix: PAnsiChar; const ASuffix: PAnsiChar;
  APathBuf: PAnsiChar; APathBufLen: Int32; out AHandle: TPlatformFileHandle): Int32;
begin
  Result := platform_fs_mktemp_impl(APathBuf, APathBufLen, APrefix, ASuffix, AHandle);
end;

function platform_fs_read_file(const APath: PAnsiChar;
  out AData: Pointer; out ALen: PtrUInt): Int32;
var
  LH: TPlatformFileHandle;
  LSize: Int64;
  LRead: PtrUInt;
  LR, LCloseR: Int32;
begin
  AData := nil;
  ALen := 0;
  LR := platform_fs_file_size(APath, LSize);
  if LR <> 0 then Exit(LR);
  if LSize = 0 then
  begin
    GetMem(AData, 1);
    PAnsiChar(AData)[0] := #0;
    ALen := 0;
    Exit(0);
  end;
  LR := platform_file_open(APath, fomReadOnly, fcmOpenExisting, LH);
  if LR <> 0 then Exit(LR);
  GetMem(AData, PtrUInt(LSize) + 1);
  LR := platform_fs_read_all(LH, AData, PtrUInt(LSize), LRead);
  LCloseR := platform_file_close(LH);
  if (LR = 0) and (LCloseR <> 0) then
    LR := LCloseR;
  if LR <> 0 then
  begin
    FreeMem(AData);
    AData := nil;
    Exit(LR);
  end;
  PAnsiChar(AData)[LRead] := #0;
  ALen := LRead;
  Result := 0;
end;

function platform_fs_read_file_into(const APath: PAnsiChar;
  ABuf: Pointer; ABufCapacity: PtrUInt; out ALen: PtrUInt): Int32;
var
  LH: TPlatformFileHandle;
  LSize: Int64;
  LRead: PtrUInt;
  LR, LCloseR: Int32;
begin
  ALen := 0;
  LR := platform_fs_file_size(APath, LSize);
  if LR <> 0 then
    Exit(LR);
  if LSize = 0 then
    Exit(0);
  if LSize > Int64(ABufCapacity) then
  begin
    ALen := PtrUInt(LSize);
    Exit(PLATFORM_FS_SHORT_READ_ERROR);
  end;
  if ABuf = nil then
    Exit(-1);
  LR := platform_file_open(APath, fomReadOnly, fcmOpenExisting, LH);
  if LR <> 0 then
    Exit(LR);
  LR := platform_fs_read_all(LH, ABuf, PtrUInt(LSize), LRead);
  LCloseR := platform_file_close(LH);
  if (LR = 0) and (LCloseR <> 0) then
    LR := LCloseR;
  ALen := LRead;
  Result := LR;
end;

procedure platform_fs_free_buf(AData: Pointer);
begin
  if AData <> nil then
    FreeMem(AData);
end;

function WalkResolveType(APathBuf: PAnsiChar; ADirType: TPlatformFileType;
  AFollowSymlinks: Boolean; out AErrCode: Int32): TPlatformFileType;
var
  LStat: TPlatformFileStat;
  LResult: Int32;
begin
  AErrCode := 0;
  if ADirType <> ftUnknown then
  begin
    if AFollowSymlinks and (ADirType = ftSymlink) then
    begin
      LResult := platform_file_stat(APathBuf, LStat);
      if LResult = 0 then
        Exit(LStat.FileType);
      AErrCode := LResult;
      Exit(ftSymlink);
    end;
    Exit(ADirType);
  end;
  if AFollowSymlinks then
  begin
    if platform_file_stat(APathBuf, LStat) = 0 then
      Exit(LStat.FileType);
  end;
  AErrCode := platform_file_lstat(APathBuf, LStat);
  if AErrCode <> 0 then
    Exit(ftUnknown);
  Result := LStat.FileType;
end;

function WalkRecurse(APathBuf: PAnsiChar; APathLen: Int32;
  ACallback: TPlatformWalkCallback; AUserData: Pointer;
  AFollowSymlinks: Boolean; ADepth: Int32): Int32;
var
  LHandle: TPlatformDirHandle;
  LDirEntry: TPlatformDirEntry;
  LEntry: TPlatformWalkEntry;
  LAction: TPlatformWalkAction;
  LChildLen, LNameLen: Int32;
  LR, LErrCode: Int32;
  LChildType: TPlatformFileType;
begin
  if ADepth >= PLATFORM_WALK_MAX_DEPTH then
    Exit(PLATFORM_WALK_COMPLETED);

  LR := platform_dir_open(APathBuf, LHandle);
  if LR <> 0 then
  begin
    FillChar(LEntry, SizeOf(LEntry), 0);
    LEntry.Path := APathBuf;
    LEntry.PathLen := APathLen;
    LEntry.Name := APathBuf;
    LEntry.NameLen := APathLen;
    LEntry.FileType := ftDirectory;
    LEntry.Depth := ADepth;
    LEntry.ErrorCode := LR;
    LAction := ACallback(LEntry, AUserData);
    if LAction = pwaStop then
      Exit(PLATFORM_WALK_STOPPED);
    Exit(PLATFORM_WALK_COMPLETED);
  end;

  while True do
  begin
    LR := platform_dir_read(LHandle, LDirEntry);
    if LR <> 0 then
      Break;

    LNameLen := LDirEntry.NameLen;
    LChildLen := APathLen + 1 + LNameLen;
    if LChildLen >= PLATFORM_FS_PATH_BUF_SIZE - 1 then
      Continue;

  {$IFDEF NEXTPAS_WINDOWS}
    APathBuf[APathLen] := '\';
  {$ELSE}
    APathBuf[APathLen] := '/';
  {$ENDIF}
    Move(LDirEntry.Name[0], APathBuf[APathLen + 1], LNameLen);
    APathBuf[LChildLen] := #0;

    LChildType := WalkResolveType(APathBuf, LDirEntry.FileType,
      AFollowSymlinks, LErrCode);

    FillChar(LEntry, SizeOf(LEntry), 0);
    LEntry.Path := APathBuf;
    LEntry.PathLen := LChildLen;
    LEntry.Name := @APathBuf[APathLen + 1];
    LEntry.NameLen := LNameLen;
    LEntry.FileType := LChildType;
    LEntry.Depth := ADepth + 1;
    LEntry.ErrorCode := LErrCode;

    LAction := ACallback(LEntry, AUserData);

    if LAction = pwaStop then
    begin
      APathBuf[APathLen] := #0;
      platform_dir_close(LHandle);
      Exit(PLATFORM_WALK_STOPPED);
    end;

    if (LAction <> pwaSkipSubtree) and (LChildType = ftDirectory) and
       (LErrCode = 0) then
    begin
      LR := WalkRecurse(APathBuf, LChildLen, ACallback, AUserData,
        AFollowSymlinks, ADepth + 1);
      if LR = PLATFORM_WALK_STOPPED then
      begin
        APathBuf[APathLen] := #0;
        platform_dir_close(LHandle);
        Exit(PLATFORM_WALK_STOPPED);
      end;
    end;

    APathBuf[APathLen] := #0;
  end;

  platform_dir_close(LHandle);
  Result := PLATFORM_WALK_COMPLETED;
end;

function platform_fs_walk(const ARoot: PAnsiChar;
  ACallback: TPlatformWalkCallback; AUserData: Pointer;
  AFollowSymlinks: Boolean): Int32;
var
  LPathBuf: array[0..PLATFORM_FS_PATH_BUF_SIZE - 1] of AnsiChar;
  LRootLen: Int32;
  LEntry: TPlatformWalkEntry;
  LAction: TPlatformWalkAction;
  LStat: TPlatformFileStat;
  LR: Int32;
  LFileType: TPlatformFileType;
begin
  if (ARoot = nil) or (ARoot[0] = #0) or (ACallback = nil) then
    Exit(PLATFORM_WALK_BADARGS);

  LRootLen := 0;
  while (LRootLen < PLATFORM_FS_PATH_BUF_SIZE - 1) and (ARoot[LRootLen] <> #0) do
  begin
    LPathBuf[LRootLen] := ARoot[LRootLen];
    Inc(LRootLen);
  end;
  while (LRootLen > 1) and ((LPathBuf[LRootLen - 1] = '/') or (LPathBuf[LRootLen - 1] = '\')) do
    Dec(LRootLen);
  LPathBuf[LRootLen] := #0;

  if AFollowSymlinks then
    LR := platform_file_stat(@LPathBuf[0], LStat)
  else
    LR := platform_file_lstat(@LPathBuf[0], LStat);

  if LR <> 0 then
    LFileType := ftUnknown
  else
    LFileType := LStat.FileType;

  FillChar(LEntry, SizeOf(LEntry), 0);
  LEntry.Path := @LPathBuf[0];
  LEntry.PathLen := LRootLen;
  LEntry.Name := @LPathBuf[0];
  LEntry.NameLen := LRootLen;
  LEntry.FileType := LFileType;
  LEntry.Depth := 0;
  if LR <> 0 then
    LEntry.ErrorCode := LR;

  LAction := ACallback(LEntry, AUserData);
  if LAction = pwaStop then
    Exit(PLATFORM_WALK_STOPPED);
  if (LAction = pwaSkipSubtree) or (LFileType <> ftDirectory) then
    Exit(PLATFORM_WALK_COMPLETED);

  Result := WalkRecurse(@LPathBuf[0], LRootLen, ACallback, AUserData,
    AFollowSymlinks, 0);
end;

end.
