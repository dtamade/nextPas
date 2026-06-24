{**
 * Unit: nextpas.core.tls.freepascal.earlydatareplay.fileprovider
 * Purpose: FreePascal early-data anti-replay 的最小本地文件型 provider prototype
 *}

unit nextpas.core.tls.freepascal.earlydatareplay.fileprovider;

{$NOTES OFF} // Suppress false-positive notes for vars passed to untyped params
{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.base.utils,
  nextpas.core.fs.stream, nextpas.core.fs, nextpas.core.path,
  nextpas.core.platform.files.base,
  nextpas.core.text.conv,
  nextpas.core.tls.base,
  nextpas.core.tls.freepascal.context.material,
  nextpas.core.tls.freepascal.earlydatareplay,
  nextpas.core.tls.freepascal.session;

type
  TFreePascalFileEarlyDataReplayStore = class(TInterfacedObject,
    IFreePascalEarlyDataReplayStore)
  private
    FFileName: string;

    function GetTempFileName: string;
    function GetLockFileName: string;
    function GetBackupFileName: string;
    function ResolveReadableStoreFileName: string;
    function OpenLockFileHandle(out ALockHandle: TPlatformFileHandle): Boolean;
    function AcquireStoreLock(out ALockHandle: TPlatformFileHandle): Boolean;
    procedure ReleaseStoreLock(var ALockHandle: TPlatformFileHandle);
  protected
    function FileExistsAt(const AFileName: string): Boolean; virtual;
    function DeleteFileAt(const AFileName: string): Boolean; virtual;
    function RenameFileAt(
      const ASourceFileName: string;
      const ADestFileName: string
    ): Boolean; virtual;
    function OpenReadFileStream(const AFileName: string): IStream; virtual;
    function OpenWriteFileStream(const AFileName: string): IStream; virtual;
  public
    constructor Create(const AFileName: string);

    function AcquireUpdateGuard(
      out AGuard: IFreePascalEarlyDataReplayStoreGuard
    ): Boolean;
    function LoadEntries(out AEntries: TFreePascalEarlyDataReplayStoreEntries): Boolean;
    function SaveEntries(const AEntries: TFreePascalEarlyDataReplayStoreEntries): Boolean;
  end;

  TFreePascalFileEarlyDataReplayProvider = class(
    TFreePascalStoreBackedEarlyDataReplayProvider)
  public
    constructor Create(const AFileName: string);
  end;

function InstallFileBackedReplayLedger(
  AContext: ISSLContext;
  const AFileName: string
): Boolean;

implementation

uses
  nextpas.core.platform.files;

const
  FREEPASCAL_FILE_REPLAY_PROVIDER_VERSION = 1;
  MAX_REPLAY_PROVIDER_ENTRY_COUNT = 100000;
  MAX_REPLAY_PROVIDER_KEY_LENGTH = 4096;

var
  GReplayFileProviderLock: TRTLCriticalSection;

type
  TFreePascalFileEarlyDataReplayStoreGuard = class(TInterfacedObject,
    IFreePascalEarlyDataReplayStoreGuard)
  private
    FOwner: TFreePascalFileEarlyDataReplayStore;
    FLockHandle: TPlatformFileHandle;
  public
    constructor Create(
      AOwner: TFreePascalFileEarlyDataReplayStore;
      const ALockHandle: TPlatformFileHandle
    );
    destructor Destroy; override;
  end;

function LockHandleIsValid(const AHandle: TPlatformFileHandle): Boolean; inline;
begin
  Result := AHandle.Value <> PLATFORM_FILE_INVALID_HANDLE.Value;
end;

constructor TFreePascalFileEarlyDataReplayStoreGuard.Create(
  AOwner: TFreePascalFileEarlyDataReplayStore;
  const ALockHandle: TPlatformFileHandle
);
begin
  inherited Create;
  FOwner := AOwner;
  FLockHandle := ALockHandle;
end;

destructor TFreePascalFileEarlyDataReplayStoreGuard.Destroy;
begin
  if FOwner <> nil then
    FOwner.ReleaseStoreLock(FLockHandle)
  else if LockHandleIsValid(FLockHandle) then
  begin
    platform_file_unlock(FLockHandle);
    platform_file_close(FLockHandle);
  end;

  LeaveCriticalSection(GReplayFileProviderLock);
  inherited Destroy;
end;

constructor TFreePascalFileEarlyDataReplayStore.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := Trim(AFileName);
end;

constructor TFreePascalFileEarlyDataReplayProvider.Create(const AFileName: string);
begin
  inherited Create(TFreePascalFileEarlyDataReplayStore.Create(AFileName));
end;

function TFreePascalFileEarlyDataReplayStore.GetTempFileName: string;
begin
  if FFileName = '' then
    Exit('');
  Result := FFileName + '.tmp';
end;

function TFreePascalFileEarlyDataReplayStore.GetLockFileName: string;
begin
  if FFileName = '' then
    Exit('');
  Result := FFileName + '.lock';
end;

function TFreePascalFileEarlyDataReplayStore.GetBackupFileName: string;
begin
  if FFileName = '' then
    Exit('');
  Result := FFileName + '.bak';
end;

function TFreePascalFileEarlyDataReplayStore.FileExistsAt(
  const AFileName: string
): Boolean;
begin
  Result := (AFileName <> '') and nextpas.core.fs.IsFile(AFileName);
end;

function TFreePascalFileEarlyDataReplayStore.DeleteFileAt(
  const AFileName: string
): Boolean;
begin
  Result := (AFileName <> '') and nextpas.core.fs.Remove(AFileName);
end;

function TFreePascalFileEarlyDataReplayStore.RenameFileAt(
  const ASourceFileName: string;
  const ADestFileName: string
): Boolean;
begin
  Result := (ASourceFileName <> '') and (ADestFileName <> '') and
    nextpas.core.fs.Rename(ASourceFileName, ADestFileName);
end;

function TFreePascalFileEarlyDataReplayStore.OpenReadFileStream(
  const AFileName: string
): IStream;
begin
  Result := FsOpen(AFileName, [fmRead]);
end;

function TFreePascalFileEarlyDataReplayStore.OpenWriteFileStream(
  const AFileName: string
): IStream;
begin
  Result := FsCreate(AFileName);
end;

function TFreePascalFileEarlyDataReplayStore.ResolveReadableStoreFileName: string;
begin
  Result := '';

  if FFileName = '' then
    Exit;
  if FileExistsAt(FFileName) then
    Exit(FFileName);

  Result := GetTempFileName;
  if (Result <> '') and FileExistsAt(Result) then
    Exit;

  Result := GetBackupFileName;
  if (Result = '') or (not FileExistsAt(Result)) then
    Result := '';
end;

function TFreePascalFileEarlyDataReplayStore.OpenLockFileHandle(
  out ALockHandle: TPlatformFileHandle
): Boolean;
var
  LLockFileName: string;
  LDir: string;
begin
  Result := False;
  ALockHandle := PLATFORM_FILE_INVALID_HANDLE;

  LLockFileName := GetLockFileName;
  if LLockFileName = '' then
    Exit;

  LDir := PathDir(LLockFileName);
  if (LDir <> '') and (not nextpas.core.fs.MkdirAll(LDir)) then
    Exit;

  Result := platform_file_open_ex(PAnsiChar(LLockFileName),
    fomReadWrite, fcmOpenOrCreate, False, False, UInt32(PermDefault),
    ALockHandle) = 0;
end;

function TFreePascalFileEarlyDataReplayStore.AcquireStoreLock(
  out ALockHandle: TPlatformFileHandle
): Boolean;
begin
  Result := False;
  ALockHandle := PLATFORM_FILE_INVALID_HANDLE;

  if not OpenLockFileHandle(ALockHandle) then
    Exit;
  if platform_file_trylock(ALockHandle, True) <> 0 then
  begin
    platform_file_close(ALockHandle);
    Exit(False);
  end;
  Result := True;
end;

procedure TFreePascalFileEarlyDataReplayStore.ReleaseStoreLock(
  var ALockHandle: TPlatformFileHandle
);
begin
  if not LockHandleIsValid(ALockHandle) then
    Exit;
  platform_file_unlock(ALockHandle);
  platform_file_close(ALockHandle);
end;

function TFreePascalFileEarlyDataReplayStore.AcquireUpdateGuard(
  out AGuard: IFreePascalEarlyDataReplayStoreGuard
): Boolean;
var
  LLockHandle: TPlatformFileHandle;
begin
  Result := False;
  AGuard := nil;
  LLockHandle := PLATFORM_FILE_INVALID_HANDLE;

  EnterCriticalSection(GReplayFileProviderLock);
  if not AcquireStoreLock(LLockHandle) then
  begin
    LeaveCriticalSection(GReplayFileProviderLock);
    Exit;
  end;

  try
    AGuard := TFreePascalFileEarlyDataReplayStoreGuard.Create(Self, LLockHandle);
    Result := AGuard <> nil;
  except
    ReleaseStoreLock(LLockHandle);
    LeaveCriticalSection(GReplayFileProviderLock);
    raise;
  end;
end;

function TFreePascalFileEarlyDataReplayStore.LoadEntries(
  out AEntries: TFreePascalEarlyDataReplayStoreEntries
): Boolean;
var
  LStream: IStream;
  LReadableFileName: string;
  LVersion: Integer;
  LCount: Integer;
  I: Integer;
  LKeyLength: Integer;
begin
  Result := False;
  SetLength(AEntries, 0);

  LReadableFileName := ResolveReadableStoreFileName;
  if LReadableFileName = '' then
    Exit(True);

  try
    LStream := OpenReadFileStream(LReadableFileName);
    try
      LStream.Read(LVersion, SizeOf(Integer));
      if LVersion <> FREEPASCAL_FILE_REPLAY_PROVIDER_VERSION then
        Exit;

      LStream.Read(LCount, SizeOf(Integer));
      if (LCount < 0) or (LCount > MAX_REPLAY_PROVIDER_ENTRY_COUNT) then
        Exit;

      SetLength(AEntries, LCount);
      for I := 0 to LCount - 1 do
      begin
        LStream.Read(LKeyLength, SizeOf(Integer));
        if (LKeyLength < 0) or (LKeyLength > MAX_REPLAY_PROVIDER_KEY_LENGTH) then
          Exit;

        SetLength(AEntries[I].Key, LKeyLength);
        if LKeyLength > 0 then
          LStream.Read(AEntries[I].Key[1], LKeyLength);

        LStream.Read(AEntries[I].ExpiresAt, SizeOf(TDateTime));
      end;

      if LStream.Position <> LStream.Size then
        Exit;

      Result := True;
    finally
    end;
  except
    Result := False;
  end;
end;

function TFreePascalFileEarlyDataReplayStore.SaveEntries(
  const AEntries: TFreePascalEarlyDataReplayStoreEntries
): Boolean;
var
  LStream: IStream;
  LTempFileName: string;
  LBackupFileName: string;
  LDir: string;
  I: Integer;
  LKeyLength: Integer;
  LVersion: Integer;
  LCount: Integer;
begin
  Result := False;

  if FFileName = '' then
    Exit;
  if Length(AEntries) > MAX_REPLAY_PROVIDER_ENTRY_COUNT then
    Exit;

  LDir := ExtractFileDir(FFileName);
  if (LDir <> '') and (not nextpas.core.fs.MkdirAll(LDir)) then
    Exit;

  LTempFileName := GetTempFileName;
  LBackupFileName := GetBackupFileName;
  if FileExistsAt(LTempFileName) then
    DeleteFileAt(LTempFileName);
  if FileExistsAt(LBackupFileName) then
    if not DeleteFileAt(LBackupFileName) then
      Exit;

  try
    try
      LStream := OpenWriteFileStream(LTempFileName);
      try
        LVersion := FREEPASCAL_FILE_REPLAY_PROVIDER_VERSION;
        LCount := Length(AEntries);
        LStream.Write(LVersion, SizeOf(Integer));
        LStream.Write(LCount, SizeOf(Integer));

        for I := 0 to High(AEntries) do
        begin
          LKeyLength := Length(AEntries[I].Key);
          if LKeyLength > MAX_REPLAY_PROVIDER_KEY_LENGTH then
            Exit;
          LStream.Write(LKeyLength, SizeOf(Integer));
          if LKeyLength > 0 then
            LStream.Write(AEntries[I].Key[1], LKeyLength);
          LStream.Write(AEntries[I].ExpiresAt, SizeOf(TDateTime));
        end;
      finally
      end;

      if not RenameFileAt(LTempFileName, FFileName) then
      begin
        if FileExistsAt(FFileName) then
        begin
          if not RenameFileAt(FFileName, LBackupFileName) then
            Exit;
          if not RenameFileAt(LTempFileName, FFileName) then
          begin
            if not RenameFileAt(LBackupFileName, FFileName) then
              Exit;
            Exit;
          end;
          if FileExistsAt(LBackupFileName) then
            DeleteFileAt(LBackupFileName);
        end
        else
          Exit;
      end;

      Result := True;
    except
      Result := False;
    end;
  finally
    if (not Result) and FileExistsAt(LTempFileName) then
      DeleteFileAt(LTempFileName);
  end;
end;

function InstallFileBackedReplayLedger(
  AContext: ISSLContext;
  const AFileName: string
): Boolean;
var
  LInstaller: IFreePascalContextEarlyDataReplayInstaller;
begin
  Result := False;

  if (AContext = nil) or (Trim(AFileName) = '') then
    Exit;
  if not Supports(AContext, IFreePascalContextEarlyDataReplayInstaller, LInstaller) then
    Exit;

  try
    Result := LInstaller.InstallFileBackedReplayLedger(AFileName);
  except
    Result := False;
  end;
end;

initialization
  InitCriticalSection(GReplayFileProviderLock);

finalization
  DoneCriticalSection(GReplayFileProviderLock);

end.
