{**
 * Unit: nextpas.core.tls.freepascal.earlydatareplay.fileprovider
 * Purpose: FreePascal early-data anti-replay 的最小本地文件型 provider prototype
 *}

unit nextpas.core.tls.freepascal.earlydatareplay.fileprovider;

{$NOTES OFF} // Suppress false-positive notes for vars passed to untyped params
{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.base.utils,
  SysUtils, nextpas.core.fs.stream, nextpas.core.fs,
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
    function OpenLockFileStream(out ALockStream: IStream): Boolean;
    function AcquireStoreLock(out ALockStream: IStream): Boolean;
    procedure ReleaseStoreLock(var ALockStream: IStream);
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

{$IFDEF UNIX}
uses
  Unix;
{$ENDIF}

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
    FLockStream: IStream;
  public
    constructor Create(
      AOwner: TFreePascalFileEarlyDataReplayStore;
      ALockStream: IStream
    );
    destructor Destroy; override;
  end;

constructor TFreePascalFileEarlyDataReplayStoreGuard.Create(
  AOwner: TFreePascalFileEarlyDataReplayStore;
  ALockStream: IStream
);
begin
  inherited Create;
  FOwner := AOwner;
  FLockStream := ALockStream;
end;

destructor TFreePascalFileEarlyDataReplayStoreGuard.Destroy;
begin
  if FOwner <> nil then
    FOwner.ReleaseStoreLock(FLockStream)
  else if FLockStream <> nil then
  begin
    FLockStream := nil;
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

function TFreePascalFileEarlyDataReplayStore.OpenLockFileStream(
  out ALockStream: IStream
): Boolean;
var
  LLockFileName: string;
  LDir: string;
  LCreateStream: IStream;
  LAttempt: Integer;
begin
  Result := False;
  ALockStream := nil;

  LLockFileName := GetLockFileName;
  if LLockFileName = '' then
    Exit;

  LDir := ExtractFileDir(LLockFileName);
  if (LDir <> '') and (not nextpas.core.fs.MkdirAll(LDir)) then
    Exit;

  for LAttempt := 1 to 2 do
  begin
    try
      ALockStream := FsOpen(LLockFileName, [fmReadWrite]);
      Exit(True);
    except
      if LAttempt = 2 then
        Exit(False);
    end;

    try
      LCreateStream := FsCreate(LLockFileName);
      try
      finally
      end;
    except
      // A concurrent creator may have won the race; the second open attempt decides.
    end;
  end;
end;

function TFreePascalFileEarlyDataReplayStore.AcquireStoreLock(
  out ALockStream: IStream
): Boolean;
begin
  Result := False;
  ALockStream := nil;

  if not OpenLockFileStream(ALockStream) then
    Exit;
  {$IFDEF UNIX}
  if FpFlock(ALockStream.Handle, LOCK_EX or LOCK_NB) <> 0 then
  begin
    ALockStream := nil;
    Exit(False);
  end;
  {$ENDIF}
  Result := True;
end;

procedure TFreePascalFileEarlyDataReplayStore.ReleaseStoreLock(
  var ALockStream: IStream
);
begin
  if ALockStream = nil then
    Exit;
  {$IFDEF UNIX}
  FpFlock(ALockStream.Handle, LOCK_UN);
  {$ENDIF}
  ALockStream := nil;
end;

function TFreePascalFileEarlyDataReplayStore.AcquireUpdateGuard(
  out AGuard: IFreePascalEarlyDataReplayStoreGuard
): Boolean;
var
  LLockStream: IStream;
begin
  Result := False;
  AGuard := nil;
  LLockStream := nil;

  EnterCriticalSection(GReplayFileProviderLock);
  if not AcquireStoreLock(LLockStream) then
  begin
    LeaveCriticalSection(GReplayFileProviderLock);
    Exit;
  end;

  try
    AGuard := TFreePascalFileEarlyDataReplayStoreGuard.Create(Self, LLockStream);
    Result := AGuard <> nil;
  except
    ReleaseStoreLock(LLockStream);
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
