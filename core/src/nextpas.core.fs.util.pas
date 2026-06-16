unit nextpas.core.fs.util;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base, nextpas.core.os.env,
  nextpas.core.fs.base,
  nextpas.core.fs.intf,
  nextpas.core.text.base;

function FsReadFile(const APath: string): TBytes;
function FsReadFileText(const APath: string): string;
function FsReadFileLines(const APath: string): TStringArray;
procedure FsWriteFile(const APath: string; const AData: TBytes;
  const APerm: TFilePermission = PermDefault);
procedure FsAppendFile(const APath: string; const AData: TBytes);
procedure FsWriteAtomic(const APath: string; const AData: TBytes;
  const APerm: TFilePermission = PermDefault);
function FsCopyFile(const ASrc, ADst: string): Int64;
function FsTempFile(const ADir, APattern: string): IFile;
function FsStat(const APath: string): TFileInfo;
function FsLstat(const APath: string): TFileInfo;
function FsExists(const APath: string): Boolean;
function FsIsDir(const APath: string): Boolean;
function FsIsFile(const APath: string): Boolean;
function FsFileSize(const APath: string): Int64;
procedure FsChmod(const APath: string; const APerm: TFilePermission);
procedure FsTruncate(const APath: string; const ASize: Int64);
procedure FsSymlink(const ATarget, ALinkPath: string);
function FsReadlink(const APath: string): string;
function FsGetCwd: string;
procedure FsSetCwd(const APath: string);
function FsGetEnv(const AName: string): string;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.utf8,
  nextpas.core.errors,
  nextpas.core.fs.errors,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.fs,
  nextpas.core.platform.random,
  nextpas.core.fs.stream;

procedure WriteAllOrRaise(const AFile: IFile; const ABuf; const ACount: SizeUInt;
  const AOp: string);
var
  LTotal, LWritten: SizeUInt;
begin
  LTotal := 0;
  while LTotal < ACount do
  begin
    LWritten := AFile.Write(PByte(@ABuf)[LTotal], ACount - LTotal);
    if LWritten = 0 then
      raise EIOError.Create(AOp + ': write returned 0');
    Inc(LTotal, LWritten);
  end;
end;

function FsReadFile(const APath: string): TBytes;
var
  LSize: Int64;
  LResult: Int32;
begin
  LResult := platform_fs_file_size(PAnsiChar(APath), LSize);
  if LResult <> 0 then
    RaiseFsError(LResult, 'read file size', APath);
  if LSize = 0 then
  begin
    Result := nil;
    Exit;
  end;
  SetLength(Result, LSize);
  LResult := platform_fs_read_file_into(PAnsiChar(APath),
    @Result[0], PtrUInt(LSize));
  if LResult <> 0 then
    RaiseFsError(LResult, 'read file', APath);
end;

procedure FsWriteFile(const APath: string; const AData: TBytes;
  const APerm: TFilePermission);
var
  LFile: IFile;
begin
  LFile := FsOpenFile(APath, [fmWrite, fmCreate, fmTruncate], APerm);
  if Length(AData) > 0 then
    WriteAllOrRaise(LFile, AData[0], SizeUInt(Length(AData)), 'write file');
  LFile.Close;
end;

procedure FsAppendFile(const APath: string; const AData: TBytes);
var
  LFile: IFile;
begin
  LFile := FsOpenFile(APath, [fmWrite, fmAppend, fmCreate], PermDefault);
  if Length(AData) > 0 then
    WriteAllOrRaise(LFile, AData[0], SizeUInt(Length(AData)), 'append file');
  LFile.Close;
end;

procedure FsWriteAtomic(const APath: string; const AData: TBytes;
  const APerm: TFilePermission);
var
  LResult: Int32;
  LPtr: Pointer;
begin
  if Length(AData) > 0 then
    LPtr := @AData[0]
  else
    LPtr := nil;
  LResult := platform_fs_write_atomic(PAnsiChar(APath), LPtr, PtrUInt(Length(AData)));
  if LResult <> 0 then
    RaiseFsError(LResult, 'atomic write', APath);
  { platform_fs_write_atomic creates with default perms; honor caller perm. }
  if APerm <> PermDefault then
  begin
    LResult := platform_file_chmod(PAnsiChar(APath), UInt32(APerm));
    if LResult <> 0 then
      RaiseFsError(LResult, 'chmod', APath);
  end;
end;

function FsCopyFile(const ASrc, ADst: string): Int64;
var
  LStat: TFileInfo;
  LResult: Int32;
begin
  LStat := FsStat(ASrc);
  LResult := platform_fs_copy_file(PAnsiChar(ASrc), PAnsiChar(ADst));
  if LResult <> 0 then
    RaiseFsError(LResult, 'copy', ASrc);
  FsChmod(ADst, LStat.Permission);
  Result := LStat.Size;
end;

function FsTempFile(const ADir, APattern: string): IFile;
const
  HEX: array[0..15] of AnsiChar = '0123456789abcdef';
  MAX_ATTEMPTS = 32;
var
  LPathBuf: array[0..1023] of AnsiChar;
  LHandle: TPlatformFileHandle;
  LResult: Int32;
  LPath: string;
  LRand: array[0..7] of Byte;
  LHex: string;
  LI, LAttempt: Integer;
begin
  { Empty ADir: defer to platform temp-dir helper (system temp). }
  if ADir = '' then
  begin
    LResult := platform_fs_mktemp_handle(PAnsiChar(APattern), PAnsiChar(''),
      @LPathBuf[0], SizeOf(LPathBuf), LHandle);
    if LResult <> 0 then
      raise EIOError.Create('mktemp failed (' + IntToStr(LResult) + ')');
    LPath := StrPas(@LPathBuf[0]);
    Result := FsFromPlatformHandle(LHandle, LPath);
    Exit;
  end;

  { Explicit ADir: create the temp file there with O_EXCL + random suffix. }
  for LAttempt := 0 to MAX_ATTEMPTS - 1 do
  begin
    if platform_random_bytes(@LRand[0], 8) <> 0 then
      raise EIOError.Create('tempfile: random source failed');
    SetLength(LHex, 16);
    for LI := 0 to 7 do
    begin
      LHex[LI * 2 + 1] := Char(HEX[(LRand[LI] shr 4) and $F]);
      LHex[LI * 2 + 2] := Char(HEX[LRand[LI] and $F]);
    end;
    LPath := ADir + '/' + APattern + LHex;
    try
      Result := FsOpenFile(LPath, [fmRead, fmWrite, fmCreate, fmExclusive], PermDefault);
      Exit;
    except
      on E: EAlreadyExistsError do
        Continue;
    end;
  end;
  raise EIOError.Create('tempfile: exhausted attempts in ' + ADir);
end;

procedure FillFileInfo(const APath: string; const LPlatStat: TPlatformFileStat;
  out AInfo: TFileInfo);
begin
  AInfo.Name := APath;
  AInfo.Size := LPlatStat.Size;
  AInfo.Permission := TFilePermission(LPlatStat.Mode and $FFF);
  AInfo.ModTime := LPlatStat.ModTime;
  AInfo.AccessTime := LPlatStat.AccessTime;
  AInfo.CreateTime := LPlatStat.CreateTime;
  AInfo.IsDir := LPlatStat.FileType = nextpas.core.platform.files.base.ftDirectory;
  AInfo.IsSymlink := LPlatStat.FileType = nextpas.core.platform.files.base.ftSymlink;
  case LPlatStat.FileType of
    nextpas.core.platform.files.base.ftRegular: AInfo.FileType := nextpas.core.fs.base.ftRegular;
    nextpas.core.platform.files.base.ftDirectory: AInfo.FileType := nextpas.core.fs.base.ftDirectory;
    nextpas.core.platform.files.base.ftSymlink: AInfo.FileType := nextpas.core.fs.base.ftSymlink;
    nextpas.core.platform.files.base.ftCharDevice: AInfo.FileType := nextpas.core.fs.base.ftCharDevice;
    nextpas.core.platform.files.base.ftBlockDevice: AInfo.FileType := nextpas.core.fs.base.ftBlockDevice;
    nextpas.core.platform.files.base.ftFifo: AInfo.FileType := nextpas.core.fs.base.ftFifo;
    nextpas.core.platform.files.base.ftSocket: AInfo.FileType := nextpas.core.fs.base.ftSocket;
  else
    AInfo.FileType := nextpas.core.fs.base.ftUnknown;
  end;
end;

function FsStat(const APath: string): TFileInfo;
var
  LPlatStat: TPlatformFileStat;
  LResult: Int32;
begin
  LResult := platform_file_stat(PAnsiChar(APath), LPlatStat);
  if LResult <> 0 then
    RaiseFsError(LResult, 'stat', APath);
  FillFileInfo(APath, LPlatStat, Result);
end;

function FsLstat(const APath: string): TFileInfo;
var
  LPlatStat: TPlatformFileStat;
  LResult: Int32;
begin
  LResult := platform_file_lstat(PAnsiChar(APath), LPlatStat);
  if LResult <> 0 then
    RaiseFsError(LResult, 'lstat', APath);
  FillFileInfo(APath, LPlatStat, Result);
end;

function FsExists(const APath: string): Boolean;
begin
  Result := platform_fs_exists(PAnsiChar(APath));
end;

function FsIsDir(const APath: string): Boolean;
begin
  Result := platform_fs_is_dir(PAnsiChar(APath));
end;

function FsIsFile(const APath: string): Boolean;
begin
  Result := platform_fs_is_file(PAnsiChar(APath));
end;

function FsFileSize(const APath: string): Int64;
var
  LResult: Int32;
begin
  LResult := platform_fs_file_size(PAnsiChar(APath), Result);
  if LResult <> 0 then
    RaiseFsError(LResult, 'file_size', APath);
end;

procedure FsChmod(const APath: string; const APerm: TFilePermission);
var
  LResult: Int32;
begin
  LResult := platform_file_chmod(PAnsiChar(APath), UInt32(APerm));
  if LResult <> 0 then
    RaiseFsError(LResult, 'chmod', APath);
end;

procedure FsTruncate(const APath: string; const ASize: Int64);
var
  LResult: Int32;
begin
  LResult := platform_file_truncate_path(PAnsiChar(APath), ASize);
  if LResult <> 0 then
    RaiseFsError(LResult, 'truncate', APath);
end;

procedure FsSymlink(const ATarget, ALinkPath: string);
var
  LResult: Int32;
begin
  LResult := platform_file_symlink(PAnsiChar(ATarget), PAnsiChar(ALinkPath));
  if LResult <> 0 then
    RaiseFsError(LResult, 'symlink', ALinkPath);
end;

function FsReadlink(const APath: string): string;
const
  BUF_SIZE = 1024;
  MAX_READLINK_BUF_SIZE = 65536;
var
  LStack: array[0..BUF_SIZE - 1] of AnsiChar;
  LLen: Int32;
  LResult: Int32;
  LHeap: array of AnsiChar;
  LBufLen: Int32;
begin
  LResult := platform_file_readlink(PAnsiChar(APath), @LStack[0], BUF_SIZE, LLen);
  if LResult <> 0 then
    RaiseFsError(LResult, 'readlink', APath);
  if LLen < BUF_SIZE - 1 then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LLen);
    Exit;
  end;

  LBufLen := BUF_SIZE * 2;
  repeat
    if LBufLen > MAX_READLINK_BUF_SIZE then
      raise EIOError.Create('readlink target too long: ' + APath);
    SetLength(LHeap, LBufLen);
    LResult := platform_file_readlink(PAnsiChar(APath), @LHeap[0], LBufLen, LLen);
    if LResult <> 0 then
      RaiseFsError(LResult, 'readlink', APath);
    if LLen < LBufLen - 1 then
    begin
      SetString(Result, PAnsiChar(@LHeap[0]), LLen);
      Exit;
    end;
    LBufLen := LBufLen * 2;
  until False;
end;

function FsReadFileText(const APath: string): string;
var
  Bytes: TBytes;
  LOffset, LLen: SizeInt;
begin
  Bytes := FsReadFile(APath);
  LOffset := 0;
  if (Length(Bytes) >= 3) and (Bytes[0] = $EF) and
    (Bytes[1] = $BB) and (Bytes[2] = $BF) then
    LOffset := 3;
  LLen := Length(Bytes) - LOffset;
  if (LLen > 0) and (not UTF8IsValid(@Bytes[LOffset], SizeUInt(LLen))) then
    raise EConvertError.Create('read file: invalid UTF-8: ' + APath);
  if LLen > 0 then
    SetString(Result, PAnsiChar(@Bytes[LOffset]), LLen)
  else
    Result := '';
end;

function FsReadFileLines(const APath: string): TStringArray;
var
  Text: string;
  I, LStart, LCount, LLen: SizeInt;
begin
  Text := FsReadFileText(APath);
  LLen := Length(Text);
  if LLen = 0 then
  begin
    Result := nil;
    Exit;
  end;
  LCount := 0;
  for I := 1 to LLen do
    if Text[I] = #10 then Inc(LCount);
  Inc(LCount);
  SetLength(Result, LCount);
  LCount := 0;
  LStart := 1;
  for I := 1 to LLen do
  begin
    if Text[I] = #10 then
    begin
      if (I > LStart) and (Text[I - 1] = #13) then
        Result[LCount] := Copy(Text, LStart, I - LStart - 1)
      else
        Result[LCount] := Copy(Text, LStart, I - LStart);
      Inc(LCount);
      LStart := I + 1;
    end;
  end;
  if LStart <= LLen then
  begin
    Result[LCount] := Copy(Text, LStart, LLen - LStart + 1);
    Inc(LCount);
  end;
  SetLength(Result, LCount);
end;

function FsGetCwd: string;
const
  CWD_STACK_BUF_SIZE = 1024;
  CWD_MAX_BUF_SIZE = 65536;
var
  LStack: array[0..CWD_STACK_BUF_SIZE - 1] of AnsiChar;
  LHeap: array of AnsiChar;
  LBufSize: SizeInt;
begin
  if platform_file_getcwd(@LStack[0], CWD_STACK_BUF_SIZE) <> nil then
  begin
    Result := StrPas(@LStack[0]);
    Exit;
  end;

  LBufSize := CWD_STACK_BUF_SIZE * 2;
  repeat
    if LBufSize > CWD_MAX_BUF_SIZE then
      raise EIOError.Create('getcwd path too long');
    SetLength(LHeap, LBufSize);
    if platform_file_getcwd(@LHeap[0], PtrUInt(LBufSize)) <> nil then
    begin
      Result := StrPas(@LHeap[0]);
      Exit;
    end;
    LBufSize := LBufSize * 2;
  until False;
end;

procedure FsSetCwd(const APath: string);
var
  LResult: Int32;
begin
  LResult := platform_file_chdir(PAnsiChar(APath));
  if LResult <> 0 then
    RaiseFsError(LResult, 'chdir', APath);
end;

function FsGetEnv(const AName: string): string;
begin
  Result := nextpas.core.os.env.GetEnvironmentVariable(AName);
end;

end.
