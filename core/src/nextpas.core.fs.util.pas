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
procedure FsWriteFileText(const APath: string; const AText: string;
  const APerm: TFilePermission = PermDefault);
procedure FsWriteFileLines(const APath: string; const ALines: TStringArray;
  const APerm: TFilePermission = PermDefault);
procedure FsAppendFile(const APath: string; const AData: TBytes);
procedure FsAppendFileText(const APath: string; const AText: string);
procedure FsAppendFileLines(const APath: string; const ALines: TStringArray);
procedure FsWriteAtomic(const APath: string; const AData: TBytes;
  const APerm: TFilePermission = PermDefault);
function FsCopyFile(const ASrc, ADst: string): Int64;
{** @desc CoW 克隆文件（reflink/clonefile），不支持时回退普通复制 *}
function FsCloneFile(const ASrc, ADst: string): Int64;
function FsTempFile(const ADir, APattern: string): IFile;
function FsTempDir(const ADir, APattern: string): string;
function FsStat(const APath: string): TFileInfo;
function FsLstat(const APath: string): TFileInfo;
function FsExists(const APath: string): Boolean;
function FsIsDir(const APath: string): Boolean;
function FsIsFile(const APath: string): Boolean;
{** @desc 是否为符号链接（不跟随链接；不存在返回 False） *}
function FsIsSymlink(const APath: string): Boolean;
{** @desc 是否为同一 inode（对齐 Go os.SameFile；lstat Dev+Ino） *}
function FsSameFile(const A, B: string): Boolean;
function FsFileSize(const APath: string): Int64;
procedure FsChmod(const APath: string; const APerm: TFilePermission);
procedure FsTruncate(const APath: string; const ASize: Int64);
procedure FsSymlink(const ATarget, ALinkPath: string);
function FsReadlink(const APath: string): string;
{ POSIX realpath：整链解析（含中间段符号链接）；路径不存在/链接环 → 异常 }
function FsRealPath(const APath: string): string;
{** @desc 创建硬链接（对齐 Go os.Link / Rust hard_link） *}
procedure FsHardLink(const AOldPath, ANewPath: string);
{** @desc 创建 FIFO 特殊文件（owner 反哺：tar fifo 完整性，对齐 Go/Rust mkfifo） *}
procedure FsMkFifo(const APath: string; const APerm: TFilePermission = PermDefault);
{** @desc 创建设备节点（owner 反哺：tar device 往返完整，经平台单缝携带 DevMajor/DevMinor）
    @note Linux 需特权，失败返回 PLATFORM_ERR_* 由调用方 fail-closed 处理 *}
procedure FsMkDevice(const APath: string; AMode: Word; ADevMajor, ADevMinor: Int64; AIsChar: Boolean);
{** @desc 设置访问/修改时间（Unix 纳秒 epoch，与 TFileInfo.ModTime 同单位） *}
procedure FsChtimes(const APath: string; const AAccessTimeNs, AModTimeNs: Int64);
{** @desc 设置所有者（对齐 Go os.Chown 跟随链接；Windows 不支持） *}
procedure FsChown(const APath: string; const AUid, AGid: UInt32);
function FsGetCwd: string;
procedure FsSetCwd(const APath: string);
function FsGetEnv(const AName: string): string;
{** @desc 确保文件存在（不存在则创建空文件，已存在则不修改） *}
procedure FsEnsureFile(const APath: string);
{** @desc 获取系统临时目录路径（不创建目录） *}
function FsGetTempDir: string;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.utf8,
  nextpas.core.text.builder,
  nextpas.core.errors,
  nextpas.core.fs.errors,
  nextpas.core.fs.path,
  nextpas.core.platform.base,
  nextpas.core.platform.error,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.fs,
  nextpas.core.platform.path,
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
  LRead: PtrUInt;
  LResult: Int32;
  LGrowData: Pointer;
  LGrowLen: PtrUInt;
begin
  Result := nil;
  LResult := platform_fs_file_size(PAnsiChar(APath), LSize);
  if LResult <> 0 then
    RaiseFsError(LResult, 'read file size', APath);
  { P1-7 fix: /proc and other virtual filesystems report size=0
    but still have content when read. Try growing read for size=0. }
  if LSize = 0 then
  begin
    LGrowData := nil;
    LGrowLen := 0;
    LResult := platform_fs_read_file(PAnsiChar(APath), LGrowData, LGrowLen);
    try
      if (LResult = 0) and (LGrowLen > 0) then
      begin
        SetLength(Result, LGrowLen);
        Move(LGrowData^, Result[0], LGrowLen);
        Exit;
      end;
    finally
      if LGrowData <> nil then
        platform_fs_free_buf(LGrowData);
    end;
    Result := nil;
    Exit;
  end;
  {$IF SizeOf(PtrUInt) < 8}
  if LSize > Int64(High(PtrUInt)) then
    raise EIOError.Create('file too large for address space: ' + APath);
  {$ENDIF}
  SetLength(Result, LSize);
  LRead := 0;
  LResult := platform_fs_read_file_into(PAnsiChar(APath),
    @Result[0], PtrUInt(LSize), LRead);
  if LResult = 0 then
  begin
    if LRead < PtrUInt(LSize) then
      SetLength(Result, LRead);
    Exit;
  end;
  if LResult = PLATFORM_FS_SHORT_READ_ERROR then
  begin
    if LRead < PtrUInt(LSize) then
    begin
      SetLength(Result, LRead);
      Exit;
    end;
    LGrowData := nil;
    LGrowLen := 0;
    LResult := platform_fs_read_file(PAnsiChar(APath), LGrowData, LGrowLen);
    try
      if LResult = 0 then
      begin
        SetLength(Result, LGrowLen);
        if LGrowLen > 0 then
          Move(LGrowData^, Result[0], LGrowLen);
        Exit;
      end;
    finally
      if LGrowData <> nil then
        platform_fs_free_buf(LGrowData);
    end;
  end;
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

procedure FsWriteFileText(const APath: string; const AText: string;
  const APerm: TFilePermission);
var
  LBytes: TBytes;
  LLen: Integer;
begin
  LLen := Length(AText);
  SetLength(LBytes, LLen);
  if LLen > 0 then
    Move(PAnsiChar(AText)^, LBytes[0], LLen);
  FsWriteFile(APath, LBytes, APerm);
end;

procedure FsWriteFileLines(const APath: string; const ALines: TStringArray;
  const APerm: TFilePermission);
var
  LBuilder: TBufStringBuilder;
  I: Integer;
begin
  LBuilder.Init(256);
  try
    for I := 0 to High(ALines) do
    begin
      LBuilder.AppendStr(ALines[I]);
      LBuilder.AppendStr(PLATFORM_LINE_ENDING);
    end;
    FsWriteFileText(APath, LBuilder.ToString, APerm);
  finally
    LBuilder.Done;
  end;
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

procedure FsAppendFileText(const APath: string; const AText: string);
var
  LBytes: TBytes;
  LLen: Integer;
begin
  LLen := Length(AText);
  SetLength(LBytes, LLen);
  if LLen > 0 then
    Move(PAnsiChar(AText)^, LBytes[0], LLen);
  FsAppendFile(APath, LBytes);
end;

procedure FsAppendFileLines(const APath: string; const ALines: TStringArray);
var
  LBuilder: TBufStringBuilder;
  I: Integer;
begin
  LBuilder.Init(256);
  try
    for I := 0 to High(ALines) do
    begin
      LBuilder.AppendStr(ALines[I]);
      LBuilder.AppendStr(PLATFORM_LINE_ENDING);
    end;
    FsAppendFileText(APath, LBuilder.ToString);
  finally
    LBuilder.Done;
  end;
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
  LResult := platform_fs_write_atomic(PAnsiChar(APath), LPtr, PtrUInt(Length(AData)),
    UInt32(APerm));
  if LResult <> 0 then
    RaiseFsError(LResult, 'atomic write', APath);
  { 临时文件已按 APerm 创建（rename 后 inode 权限不变）；此处 chmod
    兜底平台忽略创建权限的情况（如 Windows 无 mode 位）。 }
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

function FsCloneFile(const ASrc, ADst: string): Int64;
var
  LStat: TFileInfo;
  LResult: Int32;
begin
  LStat := FsStat(ASrc);
  LResult := platform_fs_clone_file(PAnsiChar(ASrc), PAnsiChar(ADst));
  if LResult <> 0 then
    RaiseFsError(LResult, 'clone', ASrc);
  FsChmod(ADst, LStat.Permission);
  Result := LStat.Size;
end;

function FsTempFile(const ADir, APattern: string): IFile;
const
  HEX: array[0..15] of AnsiChar = '0123456789abcdef';
  MAX_ATTEMPTS = 32;
  TEMP_FILE_PATH_BUF_SIZE = 1024;
var
  LPathBuf: array[0..TEMP_FILE_PATH_BUF_SIZE - 1] of AnsiChar;
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
    { P2-2 fix: Ensure consistent permissions (0644) regardless of umask,
      matching the explicit ADir path behavior. }
    platform_file_chmod(PAnsiChar(LPath), UInt32(PermDefault));
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
    LPath := ADir + PLATFORM_PATH_SEP + APattern + LHex;
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

function FsTempDir(const ADir, APattern: string): string;
const
  HEX: array[0..15] of AnsiChar = '0123456789abcdef';
  MAX_ATTEMPTS = 32;
var
  LBase, LPath: string;
  LRand: array[0..7] of Byte;
  LHex: string;
  LI, LAttempt: Integer;
  LResult: Int32;
begin
  if ADir <> '' then
    LBase := ADir
  else
    LBase := FsGetTempDir;

  for LAttempt := 0 to MAX_ATTEMPTS - 1 do
  begin
    if platform_random_bytes(@LRand[0], 8) <> 0 then
      raise EIOError.Create('tempdir: random source failed');
    SetLength(LHex, 16);
    for LI := 0 to 7 do
    begin
      LHex[LI * 2 + 1] := Char(HEX[(LRand[LI] shr 4) and $F]);
      LHex[LI * 2 + 2] := Char(HEX[LRand[LI] and $F]);
    end;
    LPath := LBase + PLATFORM_PATH_SEP + APattern + LHex;
    LResult := platform_file_mkdir(PAnsiChar(LPath), UInt32(PermDirDefault));
    if LResult = 0 then
      Exit(LPath);
    if LResult <> PLATFORM_ERR_EXIST then
      RaiseFsError(LResult, 'tempdir', LPath);
  end;
  raise EIOError.Create('tempdir: exhausted attempts in ' + LBase);
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

function FsIsSymlink(const APath: string): Boolean;
begin
  if APath = '' then
    Exit(False);
  Result := platform_fs_is_symlink(PAnsiChar(APath));
end;

function FsSameFile(const A, B: string): Boolean;
var
  LA, LB: TPlatformFileStat;
  LErr: Int32;
begin
  if (A = '') or (B = '') then
    raise EArgumentError.Create('SameFile path must not be empty');
  LErr := platform_file_lstat(PAnsiChar(A), LA);
  if LErr <> 0 then
    RaiseFsError(LErr, 'samefile', A);
  LErr := platform_file_lstat(PAnsiChar(B), LB);
  if LErr <> 0 then
    RaiseFsError(LErr, 'samefile', B);
  Result := (LA.Dev = LB.Dev) and (LA.Ino = LB.Ino);
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

procedure FsHardLink(const AOldPath, ANewPath: string);
var
  LResult: Int32;
begin
  if (AOldPath = '') or (ANewPath = '') then
    raise EArgumentError.Create('HardLink path must not be empty');
  LResult := platform_file_link(PAnsiChar(AOldPath), PAnsiChar(ANewPath));
  if LResult <> 0 then
    RaiseFsError(LResult, 'hardlink', ANewPath);
end;

procedure FsMkFifo(const APath: string; const APerm: TFilePermission);
var
  LResult: Int32;
begin
  if APath = '' then
    raise EArgumentError.Create('MkFifo path must not be empty');
  LResult := platform_file_mkfifo(PAnsiChar(APath), UInt32(APerm));
  if LResult <> 0 then
    RaiseFsError(LResult, 'mkfifo', APath);
end;

procedure FsMkDevice(const APath: string; AMode: Word; ADevMajor, ADevMinor: Int64; AIsChar: Boolean);
var
  LResult: Int32;
  LMode: UInt32;
const
  S_IFCHR = $2000; S_IFBLK = $6000;
begin
  if APath = '' then
    raise EArgumentError.Create('MkDevice path must not be empty');
  if (ADevMajor < 0) or (ADevMinor < 0) then
    raise EArgumentError.Create('MkDevice dev numbers must be non-negative');
  LMode := UInt32(AMode and $0FFF);
  if AIsChar then LMode := LMode or S_IFCHR else LMode := LMode or S_IFBLK;
  LResult := platform_file_mknod(PAnsiChar(APath), LMode, UInt32(ADevMajor), UInt32(ADevMinor));
  if LResult <> 0 then
    RaiseFsError(LResult, 'mknod', APath);
end;

procedure FsChtimes(const APath: string; const AAccessTimeNs, AModTimeNs: Int64);
var
  LResult: Int32;
begin
  if APath = '' then
    raise EArgumentError.Create('Chtimes path must not be empty');
  if (AAccessTimeNs < 0) or (AModTimeNs < 0) then
    raise EArgumentError.Create('Chtimes times must be non-negative');
  LResult := platform_file_utimens(PAnsiChar(APath), AAccessTimeNs, AModTimeNs);
  if LResult <> 0 then
    RaiseFsError(LResult, 'chtimes', APath);
end;

procedure FsChown(const APath: string; const AUid, AGid: UInt32);
var
  LResult: Int32;
begin
  if APath = '' then
    raise EArgumentError.Create('Chown path must not be empty');
  LResult := platform_file_chown(PAnsiChar(APath), AUid, AGid);
  if LResult <> 0 then
    RaiseFsError(LResult, 'chown', APath);
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

{ POSIX realpath 语义的整链解析：绝对化 → 自底向上逐段遍历，
  普通段 basename 压栈、符号链接段展开（目标相对则相对父目录拼接）
  并把已压栈普通段跟到展开目标后整链重解析；
  路径不存在 → 异常，循环防护（深度上限 40，超限视为链接环）。 }
function FsRealPath(const APath: string): string;
const
  MAX_SYMLINK_FOLLOW = 40;
var
  P, Parent, Target: string;
  Depth: Integer;
  Stack: array of string;
  I: Integer;
begin
  P := Trim(APath);
  if P = '' then
    raise EIOError.Create('realpath: empty path');
  if not FsPathIsAbs(P) then
    P := FsPathJoin([FsGetCwd, P]);
  SetLength(Stack, 0);
  Depth := 0;
  while True do
  begin
    if not FsExists(P) then
      raise ENotFoundError.Create('realpath: no such file or directory: ' + APath);
    if FsIsSymlink(P) then
    begin
      Inc(Depth);
      if Depth > MAX_SYMLINK_FOLLOW then
        raise EIOError.Create('realpath: too many levels of symbolic links: ' + APath);
      Target := FsReadlink(P);
      if not FsPathIsAbs(Target) then
        Target := FsPathJoin([FsPathDir(P), Target]);
      { 已压栈普通段跟随展开目标（目标可能本身含符号链接，整链重解析） }
      for I := High(Stack) downto 0 do
        Target := FsPathJoin([Target, Stack[I]]);
      P := FsPathClean(Target);
      SetLength(Stack, 0);
      Continue;
    end;
    { 普通段：basename 压栈，上移至父目录；到根即完成 }
    Parent := FsPathDir(P);
    if (Parent = P) or (Parent = '') then
      Break;
    SetLength(Stack, Length(Stack) + 1);
    Stack[High(Stack)] := FsPathBase(P);
    P := Parent;
  end;
  { 根 + 栈反序还原路径 }
  Result := P;
  for I := High(Stack) downto 0 do
    Result := FsPathJoin([Result, Stack[I]]);
end;

function UTF16LEToUTF8(const ABytes: PByte; AByteLen: SizeInt): string;
var
  LCode: UInt32;
  LBuilder: TBufStringBuilder;
  I: SizeInt;
begin
  LBuilder.Init(AByteLen);
  try
    I := 0;
    while I + 1 < AByteLen do
    begin
      LCode := ABytes[I] + (ABytes[I + 1] shl 8);
      Inc(I, 2);
      { Surrogate pair: high (D800-DBFF) followed by low (DC00-DFFF) }
      if (LCode >= $D800) and (LCode <= $DBFF) then
      begin
        if I + 1 < AByteLen then
        begin
          LCode := ((LCode - $D800) shl 10) +
                   (ABytes[I] + (ABytes[I + 1] shl 8) - $DC00) + $10000;
          Inc(I, 2);
          { 4-byte UTF-8 for U+10000..U+10FFFF }
          LBuilder.AppendChar(AnsiChar($F0 or (LCode shr 18)));
          LBuilder.AppendChar(AnsiChar($80 or ((LCode shr 12) and $3F)));
          LBuilder.AppendChar(AnsiChar($80 or ((LCode shr 6) and $3F)));
          LBuilder.AppendChar(AnsiChar($80 or (LCode and $3F)));
        end;
      end
      else if LCode < $80 then
        LBuilder.AppendChar(AnsiChar(LCode))
      else if LCode < $800 then
      begin
        LBuilder.AppendChar(AnsiChar($C0 or (LCode shr 6)));
        LBuilder.AppendChar(AnsiChar($80 or (LCode and $3F)));
      end
      else
      begin
        LBuilder.AppendChar(AnsiChar($E0 or (LCode shr 12)));
        LBuilder.AppendChar(AnsiChar($80 or ((LCode shr 6) and $3F)));
        LBuilder.AppendChar(AnsiChar($80 or (LCode and $3F)));
      end;
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function UTF16BEToUTF8(const ABytes: PByte; AByteLen: SizeInt): string;
var
  LCode: UInt32;
  LBuilder: TBufStringBuilder;
  I: SizeInt;
begin
  LBuilder.Init(AByteLen);
  try
    I := 0;
    while I + 1 < AByteLen do
    begin
      LCode := (ABytes[I] shl 8) + ABytes[I + 1];
      Inc(I, 2);
      { Surrogate pair: high (D800-DBFF) followed by low (DC00-DFFF) }
      if (LCode >= $D800) and (LCode <= $DBFF) then
      begin
        if I + 1 < AByteLen then
        begin
          LCode := ((LCode - $D800) shl 10) +
                   ((ABytes[I] shl 8) + ABytes[I + 1] - $DC00) + $10000;
          Inc(I, 2);
          { 4-byte UTF-8 for U+10000..U+10FFFF }
          LBuilder.AppendChar(AnsiChar($F0 or (LCode shr 18)));
          LBuilder.AppendChar(AnsiChar($80 or ((LCode shr 12) and $3F)));
          LBuilder.AppendChar(AnsiChar($80 or ((LCode shr 6) and $3F)));
          LBuilder.AppendChar(AnsiChar($80 or (LCode and $3F)));
        end;
      end
      else if LCode < $80 then
        LBuilder.AppendChar(AnsiChar(LCode))
      else if LCode < $800 then
      begin
        LBuilder.AppendChar(AnsiChar($C0 or (LCode shr 6)));
        LBuilder.AppendChar(AnsiChar($80 or (LCode and $3F)));
      end
      else
      begin
        LBuilder.AppendChar(AnsiChar($E0 or (LCode shr 12)));
        LBuilder.AppendChar(AnsiChar($80 or ((LCode shr 6) and $3F)));
        LBuilder.AppendChar(AnsiChar($80 or (LCode and $3F)));
      end;
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function FsReadFileText(const APath: string): string;
var
  Bytes: TBytes;
  LOffset, LLen, I: SizeInt;
begin
  Bytes := FsReadFile(APath);
  LOffset := 0;

  { UTF-8 BOM: EF BB BF }
  if (Length(Bytes) >= 3) and (Bytes[0] = $EF) and
    (Bytes[1] = $BB) and (Bytes[2] = $BF) then
    LOffset := 3
  { UTF-16LE BOM: FF FE → convert to UTF-8 }
  else if (Length(Bytes) >= 2) and (Bytes[0] = $FF) and (Bytes[1] = $FE) then
  begin
    Result := UTF16LEToUTF8(@Bytes[2], Length(Bytes) - 2);
    Exit;
  end
  { UTF-16BE BOM: FE FF → swap bytes, convert to UTF-8 }
  else if (Length(Bytes) >= 2) and (Bytes[0] = $FE) and (Bytes[1] = $FF) then
  begin
    Result := UTF16BEToUTF8(@Bytes[2], Length(Bytes) - 2);
    Exit;
  end;

  LLen := Length(Bytes) - LOffset;
  if (LLen > 0) and (not UTF8IsValid(@Bytes[LOffset], SizeUInt(LLen))) then
  begin
    { P1-8 fix: Non-UTF-8 without BOM — treat as Latin-1 instead of raising.
      Latin-1 is the identity map for bytes 0..255, so each byte becomes
      the corresponding Unicode code point. This handles legacy files
      (ISO-8859-1, Windows-1252 superset) gracefully. }
    SetLength(Result, LLen);
    for I := 0 to LLen - 1 do
      Result[I + 1] := Char(Bytes[LOffset + I]);
    Exit;
  end;
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

procedure FsEnsureFile(const APath: string);
var
  LFile: IFile;
begin
  try
    LFile := FsOpenFile(APath, [fmWrite, fmCreate, fmExclusive], PermDefault);
    LFile.Close;
  except
    on E: EAlreadyExistsError do
      { File already exists — this is the desired state, ignore. };
  end;
end;

function FsGetTempDir: string;
var
  LBuf: array[0..4095] of AnsiChar;
  LLen: Int32;
begin
  LLen := platform_fs_temp_dir(@LBuf[0], SizeOf(LBuf));
  if LLen <= 0 then
    raise EIOError.Create('Failed to get temp directory (code=' + IntToStr(LLen) + ')');
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(LBuf[0], Result[1], LLen);
end;

end.
