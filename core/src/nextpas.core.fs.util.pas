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
  {$IFDEF UNIX}BaseUnix,{$ENDIF}
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.fs.errors,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.fs,
  nextpas.core.platform.random,
  nextpas.core.fs.stream;

function FsReadFile(const APath: string): TBytes;
var
  LData: Pointer;
  LLen: PtrUInt;
  LResult: Int32;
begin
  LResult := platform_fs_read_file(PAnsiChar(APath), LData, LLen);
  if LResult <> 0 then
    RaiseFsError(LResult, 'read file', APath);
  try
    SetLength(Result, LLen);
    if LLen > 0 then
      Move(LData^, Result[0], LLen);
  finally
    platform_fs_free_buf(LData);
  end;
end;

procedure FsWriteFile(const APath: string; const AData: TBytes;
  const APerm: TFilePermission);
var
  LFile: IFile;
begin
  LFile := FsOpenFile(APath, [fmWrite, fmCreate, fmTruncate], APerm);
  if Length(AData) > 0 then
    LFile.Write(AData[0], SizeUInt(Length(AData)));
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
  LSrcFile, LDstFile: IFile;
  LBuf: array[0..32767] of Byte;
  LRead, LWritten, LTotal: SizeUInt;
  LStat: TFileInfo;
begin
  LSrcFile := FsOpen(ASrc, [fmRead]);
  LStat := FsStat(ASrc);
  LDstFile := FsOpenFile(ADst, [fmWrite, fmCreate, fmTruncate], LStat.Permission);
  Result := 0;
  repeat
    LRead := LSrcFile.Read(LBuf[0], SizeOf(LBuf));
    if LRead = 0 then
      Break;
    LTotal := 0;
    while LTotal < LRead do
    begin
      LWritten := LDstFile.Write(LBuf[LTotal], LRead - LTotal);
      if LWritten = 0 then
        raise EIOError.Create('copy: write returned 0');
      Inc(LTotal, LWritten);
    end;
    Inc(Result, Int64(LRead));
  until False;
  LDstFile.Sync;
  LDstFile.Close;
  LSrcFile.Close;
end;

function FsTempFile(const ADir, APattern: string): IFile;
const
  HEX: array[0..15] of AnsiChar = '0123456789abcdef';
  MAX_ATTEMPTS = 32;
var
  LPathBuf: array[0..1023] of AnsiChar;
  LFd: Int32;
  LResult: Int32;
  LPath: string;
  LRand: array[0..7] of Byte;
  LHex: string;
  LI, LAttempt: Integer;
begin
  { Empty ADir: defer to platform temp-dir helper (system temp). }
  if ADir = '' then
  begin
    LResult := platform_fs_mktemp(PAnsiChar(APattern), PAnsiChar(''),
      @LPathBuf[0], SizeOf(LPathBuf), LFd);
    if LResult <> 0 then
      raise EIOError.Create('mktemp failed (' + IntToStr(LResult) + ')');
    LPath := StrPas(@LPathBuf[0]);
    Result := FsFromHandle(LFd, LPath);
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
var
  LStack: array[0..BUF_SIZE - 1] of AnsiChar;
  LLen: Int32;
  LResult: Int32;
  LHeap: array of AnsiChar;
begin
  LResult := platform_file_readlink(PAnsiChar(APath), @LStack[0], BUF_SIZE, LLen);
  if LResult <> 0 then
    RaiseFsError(LResult, 'readlink', APath);
  if LLen < BUF_SIZE then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LLen);
    Exit;
  end;
  SetLength(LHeap, LLen + 1);
  LResult := platform_file_readlink(PAnsiChar(APath), @LHeap[0], Length(LHeap), LLen);
  if LResult <> 0 then
    RaiseFsError(LResult, 'readlink', APath);
  SetString(Result, PAnsiChar(@LHeap[0]), LLen);
end;

function FsReadFileText(const APath: string): string;
var
  Bytes: TBytes;
begin
  Bytes := FsReadFile(APath);
  if Length(Bytes) > 0 then
    SetString(Result, PAnsiChar(@Bytes[0]), Length(Bytes))
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
begin
  GetDir(0, Result);
end;

procedure FsSetCwd(const APath: string);
begin
  ChDir(APath);
end;

function FsGetEnv(const AName: string): string;
var P: PChar;
begin
  {$IFDEF UNIX}
  P := BaseUnix.fpGetEnv(PChar(AName));
  if P <> nil then Result := P else Result := '';
  {$ELSE}
  Result := nextpas.core.os.env.GetEnvironmentVariable(AName);
  {$ENDIF}
end;

end.
