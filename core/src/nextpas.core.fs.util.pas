unit nextpas.core.fs.util;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.fs.base,
  nextpas.core.fs.intf;

function FsReadFile(const APath: string): TBytes;
procedure FsWriteFile(const APath: string; const AData: TBytes;
  const APerm: TFilePermission = PermDefault);
procedure FsWriteAtomic(const APath: string; const AData: TBytes;
  const APerm: TFilePermission = PermDefault);
function FsCopyFile(const ASrc, ADst: string): Int64;
function FsTempFile(const ADir, APattern: string): IFile;
function FsStat(const APath: string): TFileInfo;
function FsExists(const APath: string): Boolean;
function FsIsDir(const APath: string): Boolean;
function FsIsFile(const APath: string): Boolean;
function FsFileSize(const APath: string): Int64;

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.fs,
  nextpas.core.fs.stream;

function FsReadFile(const APath: string): TBytes;
var
  LData: Pointer;
  LLen: PtrUInt;
  LResult: Int32;
begin
  LResult := platform_fs_read_file(PAnsiChar(APath), LData, LLen);
  if LResult <> 0 then
  begin
    if LResult = 2 then
      raise ENotFoundError.Create('file not found: ' + APath);
    raise EIOError.Create('read file failed (' + IntToStr(LResult) + '): ' + APath);
  end;
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(LData^, Result[0], LLen);
  platform_fs_free_buf(LData);
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
    raise EIOError.Create('atomic write failed (' + IntToStr(LResult) + '): ' + APath);
end;

function FsCopyFile(const ASrc, ADst: string): Int64;
var
  LSrcFile, LDstFile: IFile;
  LBuf: array[0..32767] of Byte;
  LRead, LWritten, LTotal: SizeUInt;
begin
  LSrcFile := FsOpen(ASrc, [fmRead]);
  LDstFile := FsOpenFile(ADst, [fmWrite, fmCreate, fmTruncate], PermDefault);
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
var
  LPathBuf: array[0..1023] of AnsiChar;
  LFd: Int32;
  LResult: Int32;
  LPath: string;
begin
  LResult := platform_fs_mktemp(PAnsiChar(ADir + '/' + APattern),
    PAnsiChar(''), @LPathBuf[0], SizeOf(LPathBuf), LFd);
  if LResult <> 0 then
    raise EIOError.Create('mktemp failed (' + IntToStr(LResult) + ')');
  LPath := StrPas(@LPathBuf[0]);
  Result := FsFromHandle(LFd, LPath);
end;

function FsStat(const APath: string): TFileInfo;
var
  LPlatStat: TPlatformFileStat;
  LResult: Int32;
begin
  LResult := platform_file_stat(PAnsiChar(APath), LPlatStat);
  if LResult <> 0 then
  begin
    if LResult = 2 then
      raise ENotFoundError.Create('file not found: ' + APath);
    raise EIOError.Create('stat failed (' + IntToStr(LResult) + '): ' + APath);
  end;
  Result.Name := APath;
  Result.Size := LPlatStat.Size;
  Result.Permission := TFilePermission(LPlatStat.Mode and $FFF);
  Result.ModTime := LPlatStat.ModTime;
  Result.AccessTime := LPlatStat.AccessTime;
  Result.CreateTime := LPlatStat.CreateTime;
  Result.IsDir := LPlatStat.FileType = nextpas.core.platform.files.base.ftDirectory;
  Result.IsSymlink := LPlatStat.FileType = nextpas.core.platform.files.base.ftSymlink;
  case LPlatStat.FileType of
    nextpas.core.platform.files.base.ftRegular: Result.FileType := nextpas.core.fs.base.ftRegular;
    nextpas.core.platform.files.base.ftDirectory: Result.FileType := nextpas.core.fs.base.ftDirectory;
    nextpas.core.platform.files.base.ftSymlink: Result.FileType := nextpas.core.fs.base.ftSymlink;
  else
    Result.FileType := nextpas.core.fs.base.ftUnknown;
  end;
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
    raise EIOError.Create('file_size failed (' + IntToStr(LResult) + '): ' + APath);
end;

end.
