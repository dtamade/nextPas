unit nextpas.core.fs.stream;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.fs.base,
  nextpas.core.fs.intf;

function FsOpen(const APath: string; const AMode: TFileMode): IFile;
function FsCreate(const APath: string; const APerm: TFilePermission = PermDefault): IFile;
function FsOpenFile(const APath: string; const AMode: TFileMode;
  const APerm: TFilePermission): IFile;
function FsFromHandle(const AHandle: Int32; const AName: string): IFile;

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files;

type
  TFile = class(TInterfacedObject, IReader, IWriter, IStream, IFile, IReaderAt, IWriterAt)
  private
    FHandle: TPlatformFileHandle;
    FName: string;
    FClosed: Boolean;
    procedure CheckOpen;
    procedure CheckResult(AResult: Int32; const AOp: string);
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
    function ReadAt(var ABuf; const ACount: SizeUInt; const AOffset: Int64): SizeUInt;
    function WriteAt(const ABuf; const ACount: SizeUInt; const AOffset: Int64): SizeUInt;
  end;

function ModeToOpenCreate(const AMode: TFileMode;
  out AOpen: TPlatformFileOpenMode; out ACreate: TPlatformFileCreateMode): UInt32;
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

  Result := UInt32(PermDefault);
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
  LResult: Int32;
begin
  ModeToOpenCreate(AMode, LOpen, LCreate);
  LResult := platform_file_open(PAnsiChar(APath), LOpen, LCreate, LHandle);
  if LResult <> 0 then
  begin
    case LResult of
      2: raise ENotFoundError.Create('file not found: ' + APath);
      13: raise EPermissionError.Create('permission denied: ' + APath);
      17: raise EAlreadyExistsError.Create('file exists: ' + APath);
    else
      raise EIOError.Create('open failed (' + IntToStr(LResult) + '): ' + APath);
    end;
  end;
  Result := TFile.Create(LHandle, APath);
end;

function FsFromHandle(const AHandle: Int32; const AName: string): IFile;
var
  LH: TPlatformFileHandle;
begin
  LH.Value := AHandle;
  Result := TFile.Create(LH, AName);
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

procedure TFile.CheckResult(AResult: Int32; const AOp: string);
begin
  if AResult <> 0 then
    raise EIOError.Create(AOp + ' failed (' + IntToStr(AResult) + '): ' + FName);
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
    raise EIOError.Create('read failed (' + IntToStr(LResult) + '): ' + FName);
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
    raise EIOError.Create('write failed (' + IntToStr(LResult) + '): ' + FName);
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
  CheckResult(LResult, 'seek');
  Result := LNewPos;
end;

procedure TFile.Close;
begin
  if FClosed then
    Exit;
  FClosed := True;
  platform_file_close(FHandle);
end;

function TFile.GetSize: Int64;
var
  LSaved, LEnd: Int64;
begin
  LSaved := Seek(0, soCurrent);
  LEnd := Seek(0, soEnd);
  Seek(LSaved, soBeginning);
  Result := LEnd;
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
  LResult := platform_file_stat(PAnsiChar(FName), LPlatStat);
  CheckResult(LResult, 'stat');
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
begin
  CheckOpen;
  CheckResult(platform_file_sync(FHandle), 'sync');
end;

procedure TFile.Truncate(const ASize: Int64);
begin
  CheckOpen;
  CheckResult(platform_file_truncate(FHandle, ASize), 'truncate');
end;

function TFile.ReadAt(var ABuf; const ACount: SizeUInt; const AOffset: Int64): SizeUInt;
var
  LSaved: Int64;
begin
  CheckOpen;
  LSaved := Seek(0, soCurrent);
  Seek(AOffset, soBeginning);
  Result := Read(ABuf, ACount);
  Seek(LSaved, soBeginning);
end;

function TFile.WriteAt(const ABuf; const ACount: SizeUInt; const AOffset: Int64): SizeUInt;
var
  LSaved: Int64;
begin
  CheckOpen;
  LSaved := Seek(0, soCurrent);
  Seek(AOffset, soBeginning);
  Result := Write(ABuf, ACount);
  Seek(LSaved, soBeginning);
end;

end.