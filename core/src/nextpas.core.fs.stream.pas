unit nextpas.core.fs.stream;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.platform.files.base,
  nextpas.core.fs.base,
  nextpas.core.fs.intf,
  nextpas.core.platform.sendfile.base;

function FsOpen(const APath: string; const AMode: TFileMode): IFile;
function FsCreate(const APath: string; const APerm: TFilePermission = PermDefault): IFile;
function FsOpenFile(const APath: string; const AMode: TFileMode;
  const APerm: TFilePermission): IFile;
function FsFromHandle(const AHandle: Int32; const AName: string): IFile;
{ Takes ownership of AHandle; the returned IFile closes it. }
function FsFromPlatformHandle(const AHandle: TPlatformFileHandle;
  const AName: string): IFile;
{ Open then Lock; on lock failure closes the file and re-raises. }
function FsOpenLocked(const APath: string;
  const AMode: TFileMode = [fmRead, fmWrite];
  const AKind: TFileLockKind = flkExclusive): IFile;

implementation

uses
  nextpas.core.errors,
  nextpas.core.fs.errors,
  nextpas.core.platform.files,
  nextpas.core.platform.sendfile;

type
  IFilePlatformHandle = interface
    ['{7A8E9F3C-5B4A-4E2D-9C1F-3D2E1F0A9B8C}']
    function GetPlatformHandle: TPlatformFileHandle;
  end;

  TFile = class(TInterfacedObject, IReader, IWriter, IStream, IFile, IReaderAt, IWriterAt, IWriterTo, IFilePlatformHandle, nextpas.core.platform.sendfile.base.ISendfileFileHandle)
  private
    FHandle: TPlatformFileHandle;
    FName: string;
    FClosed: Boolean;
    procedure CheckOpen;
  public
    constructor Create(const AHandle: TPlatformFileHandle; const AName: string);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function Name: string;
    function Stat: TFileInfo;
    procedure Sync;
    procedure Truncate(const ASize: Int64);
    procedure Lock(const AKind: TFileLockKind = flkExclusive);
    function TryLock(const AKind: TFileLockKind = flkExclusive): Boolean;
    procedure Unlock;
    function ReadAt(var ABuf; const ACount: SizeUInt; const AOffset: Int64): SizeUInt;
    function WriteAt(const ABuf; const ACount: SizeUInt; const AOffset: Int64): SizeUInt;
    function WriteTo(const ADst: IWriter): Int64;
    function GetPlatformHandle: TPlatformFileHandle;
    function GetFileHandle: TPlatformFileHandle;
  end;

procedure ModeToOpenCreate(const AMode: TFileMode;
  out AOpen: TPlatformFileOpenMode; out ACreate: TPlatformFileCreateMode;
  out AAppend, ASync: Boolean);
var
  LHasRead, LHasWrite: Boolean;
begin
  LHasRead := fmRead in AMode;
  LHasWrite := (fmWrite in AMode) or (fmAppend in AMode);

  if LHasRead and LHasWrite then
    AOpen := fomReadWrite
  else if LHasWrite then
    AOpen := fomWriteOnly
  else
    AOpen := fomReadOnly;

  if fmExclusive in AMode then
    ACreate := fcmCreateNew
  else if fmCreate in AMode then
  begin
    if fmTruncate in AMode then
      ACreate := fcmCreateAlways
    else
      ACreate := fcmOpenOrCreate;
  end
  else if fmTruncate in AMode then
    ACreate := fcmTruncateExisting
  else
    ACreate := fcmOpenExisting;

  AAppend := fmAppend in AMode;
  ASync := fmSync in AMode;
end;

function PlatformFileTypeToFileType(AFt: TPlatformFileType): TFileType;
begin
  case AFt of
    nextpas.core.platform.files.base.ftRegular: Result := nextpas.core.fs.base.ftRegular;
    nextpas.core.platform.files.base.ftDirectory: Result := nextpas.core.fs.base.ftDirectory;
    nextpas.core.platform.files.base.ftSymlink: Result := nextpas.core.fs.base.ftSymlink;
    nextpas.core.platform.files.base.ftCharDevice: Result := nextpas.core.fs.base.ftCharDevice;
    nextpas.core.platform.files.base.ftBlockDevice: Result := nextpas.core.fs.base.ftBlockDevice;
    nextpas.core.platform.files.base.ftFifo: Result := nextpas.core.fs.base.ftFifo;
    nextpas.core.platform.files.base.ftSocket: Result := nextpas.core.fs.base.ftSocket;
  else
    Result := nextpas.core.fs.base.ftUnknown;
  end;
end;

{ Factory functions }

function FsOpen(const APath: string; const AMode: TFileMode): IFile;
begin
  Result := FsOpenFile(APath, AMode, PermDefault);
end;

function FsCreate(const APath: string; const APerm: TFilePermission): IFile;
begin
  Result := FsOpenFile(APath, [fmRead, fmWrite, fmCreate, fmTruncate], APerm);
end;

function FsOpenFile(const APath: string; const AMode: TFileMode;
  const APerm: TFilePermission): IFile;
var
  LHandle: TPlatformFileHandle;
  LOpen: TPlatformFileOpenMode;
  LCreate: TPlatformFileCreateMode;
  LAppend, LSync: Boolean;
  LResult: Int32;
begin
  ModeToOpenCreate(AMode, LOpen, LCreate, LAppend, LSync);
  LResult := platform_file_open_ex(PAnsiChar(APath), LOpen, LCreate,
    LAppend, LSync, UInt32(APerm), LHandle);
  if LResult <> 0 then
    RaiseFsError(LResult, 'open', APath);
  Result := TFile.Create(LHandle, APath);
end;

function FsFromHandle(const AHandle: Int32; const AName: string): IFile;
var
  LH: TPlatformFileHandle;
begin
{$IFDEF NEXTPAS_WINDOWS}
  LH.Value := Pointer(PtrInt(AHandle));
{$ELSE}
  LH.Value := AHandle;
{$ENDIF}
  Result := TFile.Create(LH, AName);
end;

function FsFromPlatformHandle(const AHandle: TPlatformFileHandle;
  const AName: string): IFile;
begin
  Result := TFile.Create(AHandle, AName);
end;

function FsOpenLocked(const APath: string; const AMode: TFileMode;
  const AKind: TFileLockKind): IFile;
var
  LFile: IFile;
begin
  LFile := FsOpenFile(APath, AMode, PermDefault);
  try
    LFile.Lock(AKind);
  except
    try
      LFile.Close;
    except
      // Preserve original Lock exception; Close failure is secondary.
    end;
    LFile := nil;
    raise;
  end;
  Result := LFile;
end;

{ TFile }

constructor TFile.Create(const AHandle: TPlatformFileHandle; const AName: string);
begin
  inherited Create;
  FHandle := AHandle;
  FName := AName;
  FClosed := False;
end;

destructor TFile.Destroy;
begin
  if not FClosed then
    platform_file_close(FHandle);
  inherited;
end;

procedure TFile.CheckOpen;
begin
  if FClosed then
    raise EInvalidOperationError.Create('file is closed');
end;

function TFile.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LBytesRead: PtrUInt;
  LResult: Int32;
begin
  CheckOpen;
  if ACount = 0 then
    Exit(0);
  LResult := platform_file_read(FHandle, @ABuf, ACount, LBytesRead);
  if LResult <> 0 then
    RaiseFsError(LResult, 'read', FName);
  Result := LBytesRead;
end;

function TFile.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LBytesWritten: PtrUInt;
  LResult: Int32;
begin
  CheckOpen;
  if ACount = 0 then
    Exit(0);
  LResult := platform_file_write(FHandle, @ABuf, ACount, LBytesWritten);
  if LResult <> 0 then
    RaiseFsError(LResult, 'write', FName);
  Result := LBytesWritten;
end;

function TFile.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
var
  LNewPos: Int64;
  LOrigin: TPlatformFileSeekOrigin;
  LResult: Int32;
begin
  CheckOpen;
  case AOrigin of
    soBeginning: LOrigin := fsoBegin;
    soCurrent: LOrigin := fsoCurrent;
    soEnd: LOrigin := fsoEnd;
  end;
  LResult := platform_file_seek(FHandle, AOffset, LOrigin, LNewPos);
  if LResult <> 0 then
    RaiseFsError(LResult, 'seek', FName);
  Result := LNewPos;
end;

procedure TFile.Close;
var
  LResult: Int32;
begin
  if FClosed then
    Exit;
  LResult := platform_file_close(FHandle);
  FClosed := True;
  if LResult <> 0 then
    RaiseFsError(LResult, 'close', FName);
end;

function TFile.GetSize: Int64;
var
  LStat: TPlatformFileStat;
  LResult: Int32;
begin
  CheckOpen;
  LResult := platform_file_fstat(FHandle, LStat);
  if LResult <> 0 then
    RaiseFsError(LResult, 'fstat', FName);
  Result := LStat.Size;
end;

function TFile.GetPosition: Int64;
begin
  Result := Seek(0, soCurrent);
end;

procedure TFile.SetPosition(const AValue: Int64);
begin
  Seek(AValue, soBeginning);
end;

function TFile.Name: string;
begin
  Result := FName;
end;

function TFile.Stat: TFileInfo;
var
  LPlatStat: TPlatformFileStat;
  LResult: Int32;
begin
  CheckOpen;
  LResult := platform_file_fstat(FHandle, LPlatStat);
  if LResult <> 0 then
    RaiseFsError(LResult, 'fstat', FName);
  Result.Name := FName;
  Result.Size := LPlatStat.Size;
  Result.FileType := PlatformFileTypeToFileType(LPlatStat.FileType);
  Result.Permission := TFilePermission(LPlatStat.Mode and $FFF);
  Result.ModTime := LPlatStat.ModTime;
  Result.AccessTime := LPlatStat.AccessTime;
  Result.CreateTime := LPlatStat.CreateTime;
  Result.IsDir := LPlatStat.FileType = nextpas.core.platform.files.base.ftDirectory;
  Result.IsSymlink := LPlatStat.FileType = nextpas.core.platform.files.base.ftSymlink;
end;

procedure TFile.Sync;
var
  LResult: Int32;
begin
  CheckOpen;
  LResult := platform_file_sync(FHandle);
  if LResult <> 0 then
    RaiseFsError(LResult, 'sync', FName);
end;

procedure TFile.Truncate(const ASize: Int64);
var
  LResult: Int32;
begin
  CheckOpen;
  LResult := platform_file_truncate(FHandle, ASize);
  if LResult <> 0 then
    RaiseFsError(LResult, 'truncate', FName);
end;

procedure TFile.Lock(const AKind: TFileLockKind);
var
  LResult: Int32;
begin
  CheckOpen;
  LResult := platform_file_lock(FHandle, AKind = flkExclusive);
  if LResult <> 0 then
    RaiseFsError(LResult, 'lock', FName);
end;

function TFile.TryLock(const AKind: TFileLockKind): Boolean;
var
  LResult: Int32;
begin
  CheckOpen;
  LResult := platform_file_trylock(FHandle, AKind = flkExclusive);
  if LResult = 0 then
    Exit(True);
  if FsIsLockBusy(LResult) then
    Exit(False);
  RaiseFsError(LResult, 'trylock', FName);
  Result := False;
end;

procedure TFile.Unlock;
var
  LResult: Int32;
begin
  CheckOpen;
  LResult := platform_file_unlock(FHandle);
  if LResult <> 0 then
    RaiseFsError(LResult, 'unlock', FName);
end;

function TFile.ReadAt(var ABuf; const ACount: SizeUInt; const AOffset: Int64): SizeUInt;
var
  LBytesRead: PtrUInt;
  LResult: Int32;
begin
  CheckOpen;
  if ACount = 0 then
    Exit(0);
  LResult := platform_file_pread(FHandle, @ABuf, ACount, AOffset, LBytesRead);
  if LResult <> 0 then
    RaiseFsError(LResult, 'pread', FName);
  Result := LBytesRead;
end;

function TFile.WriteAt(const ABuf; const ACount: SizeUInt; const AOffset: Int64): SizeUInt;
var
  LBytesWritten: PtrUInt;
  LResult: Int32;
begin
  CheckOpen;
  if ACount = 0 then
    Exit(0);
  LResult := platform_file_pwrite(FHandle, @ABuf, ACount, AOffset, LBytesWritten);
  if LResult <> 0 then
    RaiseFsError(LResult, 'pwrite', FName);
  Result := LBytesWritten;
end;

function TFile.GetPlatformHandle: TPlatformFileHandle;
begin
  Result := FHandle;
end;

function TFile.GetFileHandle: TPlatformFileHandle;
begin
  Result := FHandle;
end;

function TFile.WriteTo(const ADst: IWriter): Int64;
var
  LBuf: array[0..32767] of Byte; { IO_COPY_BUF_SIZE single source, 32K = 8*4K }
  LRead, LWritten, LTotal: SizeUInt;
  LFileDst: IFilePlatformHandle;
  LDstHandle: TPlatformFileHandle;
  LSocketDst: nextpas.core.platform.sendfile.base.ISendfileSocketHandle;
  LSocketHandle: TPlatformSocket;
  LOffset: Int64;
  LRemaining: Int64;
  LSent: Int64;
  LChunk: Int64;
begin
  if ADst = nil then
    raise EArgumentNil.Create('TFile.WriteTo: destination writer is nil');
  CheckOpen;
  { L0 `platform.sendfile` 已兑现：file→file 真零拷贝（Linux `sendfile` file→file 2.6.33+）；
    file→socket 内核零拷贝已兑现（Linux `sendfile` file→socket）via IWriter fd 缝
    `ISendfileSocketHandle`，通用 `IWriter` 回退 honest 32K 缓冲（`bytes.ops` `Move` 单源，
    `IWriterTo` 快路径已打通，`PLATFORM_SENDFILE_CHUNK`/`IO_COPY_BUF_SIZE` 单源，`try/finally`/`Close` 不丢）。 }
  if Supports(ADst, IFilePlatformHandle, LFileDst) then
  begin
    LDstHandle := LFileDst.GetPlatformHandle;
    if not LDstHandle.IsInvalid and not FHandle.IsInvalid then
    begin
      LOffset := GetPosition;
      LRemaining := GetSize - LOffset;
      if LRemaining > 0 then
      begin
        LSent := platform_sendfile_file(LDstHandle, FHandle, @LOffset, LRemaining);
        if LSent > 0 then
        begin
          Seek(LOffset, soBeginning);
          Exit(LSent);
        end;
      end else if LRemaining = 0 then
        Exit(0);
    end;
  end;
  if Supports(ADst, nextpas.core.platform.sendfile.base.ISendfileSocketHandle, LSocketDst) then
  begin
    LSocketHandle := LSocketDst.GetSocketHandle;
    if not LSocketHandle.IsInvalid and not FHandle.IsInvalid then
    begin
      LOffset := GetPosition;
      LRemaining := GetSize - LOffset;
      if LRemaining = 0 then
        Exit(0);
      if LRemaining > 0 then
      begin
        Result := 0;
        while LRemaining > 0 do
        begin
          if LRemaining > PLATFORM_SENDFILE_CHUNK then
            LChunk := PLATFORM_SENDFILE_CHUNK
          else
            LChunk := LRemaining;
          LSent := platform_sendfile_socket(LSocketHandle, FHandle, @LOffset, LChunk);
          if LSent = PLATFORM_SENDFILE_UNSUPPORTED then
            Break;
          if LSent <= 0 then
            Break;
          Inc(Result, LSent);
          Dec(LRemaining, LSent);
        end;
        if Result > 0 then
        begin
          Seek(LOffset, soBeginning);
          Exit(Result);
        end;
      end;
    end;
  end;
  Result := 0;
  repeat
    LRead := Read(LBuf[0], SizeOf(LBuf));
    if LRead = 0 then
      Break;
    LTotal := 0;
    while LTotal < LRead do
    begin
      LWritten := ADst.Write(LBuf[LTotal], LRead - LTotal);
      if LWritten = 0 then
        raise EIOError.Create('TFile.WriteTo: write returned 0');
      if LWritten > LRead - LTotal then
        raise EIOError.Create('TFile.WriteTo: writer over-reported bytes');
      Inc(LTotal, LWritten);
    end;
    Inc(Result, Int64(LRead));
  until False;
end;

end.
