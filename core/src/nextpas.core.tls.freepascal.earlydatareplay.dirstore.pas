{**
 * Unit: nextpas.core.tls.freepascal.earlydatareplay.dirstore
 * Purpose: FreePascal early-data anti-replay 的目录型本地 store prototype
 *}

unit nextpas.core.tls.freepascal.earlydatareplay.dirstore;

{$mode ObjFPC}{$H+}
{$NOTES OFF} // Suppress false-positive notes for vars passed to untyped params

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.fs.stream, nextpas.core.fs, nextpas.core.fs.glob,
  nextpas.core.platform.files.base,
  nextpas.core.tls.freepascal.session;

type
  TFreePascalDirectoryEarlyDataReplayStore = class;

  TFreePascalDirectoryEarlyDataReplayStoreGuard = class(TInterfacedObject,
    IFreePascalEarlyDataReplayStoreGuard)
  private
    FOwner: TFreePascalDirectoryEarlyDataReplayStore;
    FLockHandle: TPlatformFileHandle;
  public
    constructor Create(
      AOwner: TFreePascalDirectoryEarlyDataReplayStore;
      const ALockHandle: TPlatformFileHandle
    );
    destructor Destroy; override;
  end;

  TFreePascalDirectoryEarlyDataReplayStore = class(TInterfacedObject,
    IFreePascalEarlyDataReplayStore)
  private
    FDirectoryName: string;

    function GetLockFileName: string;
    function GetTempDirectoryName: string;
    function GetBackupDirectoryName: string;
    function PathExistsAt(const APath: string): Boolean;
    function EncodeKey(const AKey: string): string;
    function TryDecodeKey(const AEncodedKey: string; out AKey: string): Boolean;
    function ResolveReadableDirectoryName(out ADirectoryName: string): Boolean;
    function LoadEntriesFromDirectory(
      const ADirectoryName: string;
      out AEntries: TFreePascalEarlyDataReplayStoreEntries
    ): Boolean;
    function OpenLockFileHandle(out ALockHandle: TPlatformFileHandle): Boolean;
    function AcquireStoreLock(out ALockHandle: TPlatformFileHandle): Boolean;
    procedure ReleaseStoreLock(var ALockHandle: TPlatformFileHandle);
    function WriteSnapshotDirectory(
      const ADirectoryName: string;
      const AEntries: TFreePascalEarlyDataReplayStoreEntries
    ): Boolean;
    function TryLoadEntry(
      const AFileName: string;
      const AEncodedKey: string;
      out AEntry: TFreePascalEarlyDataReplayStoreEntry
    ): Boolean;
  protected
    function RenamePathAt(
      const ASourcePath: string;
      const ADestPath: string
    ): Boolean; virtual;
    function RemovePathTree(const APath: string): Boolean; virtual;
  public
    constructor Create(const ADirectoryName: string);

    function AcquireUpdateGuard(
      out AGuard: IFreePascalEarlyDataReplayStoreGuard
    ): Boolean;
    function LoadEntries(
      out AEntries: TFreePascalEarlyDataReplayStoreEntries
    ): Boolean;
    function SaveEntries(
      const AEntries: TFreePascalEarlyDataReplayStoreEntries
    ): Boolean;
  end;

implementation

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.platform.files;

const
  FREEPASCAL_DIRECTORY_REPLAY_STORE_VERSION = 1;
  MAX_REPLAY_PROVIDER_ENTRY_COUNT = 100000;
  MAX_REPLAY_PROVIDER_KEY_LENGTH = 4096;
  DIRECTORY_REPLAY_ENTRY_SUFFIX = '.entry';
  HEX_DIGITS: array[0..15] of Char = '0123456789abcdef';

var
  GReplayDirectoryStoreLock: TRTLCriticalSection;

function HexValue(AChar: Char): Integer;
begin
  case AChar of
    '0'..'9':
      Result := Ord(AChar) - Ord('0');
    'a'..'f':
      Result := Ord(AChar) - Ord('a') + 10;
    'A'..'F':
      Result := Ord(AChar) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

function LockHandleIsValid(const AHandle: TPlatformFileHandle): Boolean; inline;
begin
  Result := AHandle.Value <> PLATFORM_FILE_INVALID_HANDLE.Value;
end;

constructor TFreePascalDirectoryEarlyDataReplayStoreGuard.Create(
  AOwner: TFreePascalDirectoryEarlyDataReplayStore;
  const ALockHandle: TPlatformFileHandle
);
begin
  inherited Create;
  FOwner := AOwner;
  FLockHandle := ALockHandle;
end;

destructor TFreePascalDirectoryEarlyDataReplayStoreGuard.Destroy;
begin
  if FOwner <> nil then
    FOwner.ReleaseStoreLock(FLockHandle)
  else if LockHandleIsValid(FLockHandle) then
  begin
    platform_file_unlock(FLockHandle);
    platform_file_close(FLockHandle);
  end;

  LeaveCriticalSection(GReplayDirectoryStoreLock);
  inherited Destroy;
end;

constructor TFreePascalDirectoryEarlyDataReplayStore.Create(
  const ADirectoryName: string
);
begin
  inherited Create;
  FDirectoryName := Trim(ADirectoryName);
end;

function TFreePascalDirectoryEarlyDataReplayStore.GetLockFileName: string;
begin
  if FDirectoryName = '' then
    Exit('');
  Result := FDirectoryName + '.lock';
end;

function TFreePascalDirectoryEarlyDataReplayStore.GetTempDirectoryName: string;
begin
  if FDirectoryName = '' then
    Exit('');
  Result := FDirectoryName + '.tmpdir';
end;

function TFreePascalDirectoryEarlyDataReplayStore.GetBackupDirectoryName: string;
begin
  if FDirectoryName = '' then
    Exit('');
  Result := FDirectoryName + '.bakdir';
end;

function TFreePascalDirectoryEarlyDataReplayStore.PathExistsAt(
  const APath: string
): Boolean;
begin
  Result := (APath <> '') and (nextpas.core.fs.IsFile(APath) or nextpas.core.fs.IsDir(APath));
end;

function TFreePascalDirectoryEarlyDataReplayStore.EncodeKey(
  const AKey: string
): string;
var
  I: Integer;
  LByte: Byte;
begin
  SetLength(Result, Length(AKey) * 2);
  for I := 1 to Length(AKey) do
  begin
    LByte := Byte(AKey[I]);
    Result[(I - 1) * 2 + 1] := HEX_DIGITS[(LByte shr 4) and $0F];
    Result[(I - 1) * 2 + 2] := HEX_DIGITS[LByte and $0F];
  end;
end;

function TFreePascalDirectoryEarlyDataReplayStore.TryDecodeKey(
  const AEncodedKey: string;
  out AKey: string
): Boolean;
var
  I: Integer;
  LHi: Integer;
  LLo: Integer;
begin
  Result := False;
  AKey := '';

  if (Length(AEncodedKey) mod 2) <> 0 then
    Exit;

  SetLength(AKey, Length(AEncodedKey) div 2);
  for I := 0 to Length(AKey) - 1 do
  begin
    LHi := HexValue(AEncodedKey[I * 2 + 1]);
    LLo := HexValue(AEncodedKey[I * 2 + 2]);
    if (LHi < 0) or (LLo < 0) then
      Exit(False);
    AKey[I + 1] := Char((LHi shl 4) or LLo);
  end;

  Result := True;
end;

function TFreePascalDirectoryEarlyDataReplayStore.ResolveReadableDirectoryName(
  out ADirectoryName: string
): Boolean;
var
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
begin
  Result := False;
  ADirectoryName := '';

  if FDirectoryName = '' then
    Exit;

  if PathExistsAt(FDirectoryName) then
  begin
    if not nextpas.core.fs.IsDir(FDirectoryName) then
      Exit(False);
    ADirectoryName := FDirectoryName;
    Exit(True);
  end;

  LTempDirectoryName := GetTempDirectoryName;
  if PathExistsAt(LTempDirectoryName) then
  begin
    if not nextpas.core.fs.IsDir(LTempDirectoryName) then
      Exit(False);
    ADirectoryName := LTempDirectoryName;
    Exit(True);
  end;

  LBackupDirectoryName := GetBackupDirectoryName;
  if PathExistsAt(LBackupDirectoryName) then
  begin
    if not nextpas.core.fs.IsDir(LBackupDirectoryName) then
      Exit(False);
    ADirectoryName := LBackupDirectoryName;
    Exit(True);
  end;

  Result := True;
end;

function TFreePascalDirectoryEarlyDataReplayStore.LoadEntriesFromDirectory(
  const ADirectoryName: string;
  out AEntries: TFreePascalEarlyDataReplayStoreEntries
): Boolean;
var
  LDirectoryEntries: TDirEntryArray;
  LEntryFiles: TStringArray;
  LEntry: TFreePascalEarlyDataReplayStoreEntry;
  LEntryPath: string;
  LEncodedKey: string;
  I: Integer;
begin
  Result := False;
  SetLength(AEntries, 0);

  if ADirectoryName = '' then
    Exit;
  if not nextpas.core.fs.IsDir(ADirectoryName) then
    Exit(False);

  LDirectoryEntries := nextpas.core.fs.ReadDir(ADirectoryName);
  LEntryFiles := FsGlob(ADirectoryName, '*');
  if Length(LEntryFiles) <> Length(LDirectoryEntries) then
    Exit(False);
  if Length(LEntryFiles) > MAX_REPLAY_PROVIDER_ENTRY_COUNT then
    Exit(False);

  SetLength(AEntries, Length(LEntryFiles));
  for I := 0 to High(LEntryFiles) do
  begin
    LEntryPath := LEntryFiles[I];
    LEncodedKey := nextpas.core.fs.PathBase(LEntryPath);
    if (Length(LEncodedKey) <= Length(DIRECTORY_REPLAY_ENTRY_SUFFIX)) or
      (Copy(
          LEncodedKey,
          Length(LEncodedKey) - Length(DIRECTORY_REPLAY_ENTRY_SUFFIX) + 1,
          Length(DIRECTORY_REPLAY_ENTRY_SUFFIX)
        ) <> DIRECTORY_REPLAY_ENTRY_SUFFIX) then
      Exit(False);

    LEncodedKey := Copy(
      LEncodedKey,
      1,
      Length(LEncodedKey) - Length(DIRECTORY_REPLAY_ENTRY_SUFFIX)
    );
    if not TryLoadEntry(LEntryPath, LEncodedKey, LEntry) then
      Exit(False);
    AEntries[I] := LEntry;
  end;

  Result := True;
end;

function TFreePascalDirectoryEarlyDataReplayStore.OpenLockFileHandle(
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

  LDir := nextpas.core.fs.PathDir(LLockFileName);
  if (LDir <> '') and (not nextpas.core.fs.MkdirAll(LDir)) then
    Exit;

  Result := platform_file_open_ex(PAnsiChar(LLockFileName),
    fomReadWrite, fcmOpenOrCreate, False, False, UInt32(PermDefault),
    ALockHandle) = 0;
end;

function TFreePascalDirectoryEarlyDataReplayStore.AcquireStoreLock(
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

procedure TFreePascalDirectoryEarlyDataReplayStore.ReleaseStoreLock(
  var ALockHandle: TPlatformFileHandle
);
begin
  if not LockHandleIsValid(ALockHandle) then
    Exit;
  platform_file_unlock(ALockHandle);
  platform_file_close(ALockHandle);
end;

function TFreePascalDirectoryEarlyDataReplayStore.RemovePathTree(
  const APath: string
): Boolean;
begin
  Result := False;

  if APath = '' then
    Exit(True);
  if nextpas.core.fs.IsFile(APath) then
    Exit(nextpas.core.fs.Remove(APath));
  if not nextpas.core.fs.IsDir(APath) then
    Exit(True);
  Result := nextpas.core.fs.RemoveAll(APath);
end;

function TFreePascalDirectoryEarlyDataReplayStore.RenamePathAt(
  const ASourcePath: string;
  const ADestPath: string
): Boolean;
begin
  Result := nextpas.core.fs.Rename(ASourcePath, ADestPath);
end;

function TFreePascalDirectoryEarlyDataReplayStore.WriteSnapshotDirectory(
  const ADirectoryName: string;
  const AEntries: TFreePascalEarlyDataReplayStoreEntries
): Boolean;
var
  LStream: IStream;
  LFileName: string;
  I: Integer;
  LVersion: Integer;
begin
  Result := False;

  if (ADirectoryName = '') or (not nextpas.core.fs.MkdirAll(ADirectoryName)) then
    Exit;

  try
    for I := 0 to High(AEntries) do
    begin
      if (AEntries[I].Key = '') or
        (Length(AEntries[I].Key) > MAX_REPLAY_PROVIDER_KEY_LENGTH) then
        Exit(False);

      LFileName := nextpas.core.fs.PathEnsureSep(ADirectoryName) +
        EncodeKey(AEntries[I].Key) + DIRECTORY_REPLAY_ENTRY_SUFFIX;
      LStream := FsCreate(LFileName);
      try
        LVersion := FREEPASCAL_DIRECTORY_REPLAY_STORE_VERSION;
        LStream.Write(LVersion, SizeOf(Integer));
        LStream.Write(AEntries[I].ExpiresAt, SizeOf(TDateTime));
      finally
      end;
    end;

    Result := True;
  except
    Result := False;
  end;
end;

function TFreePascalDirectoryEarlyDataReplayStore.TryLoadEntry(
  const AFileName: string;
  const AEncodedKey: string;
  out AEntry: TFreePascalEarlyDataReplayStoreEntry
): Boolean;
var
  LStream: IStream;
  LVersion: Integer;
begin
  Result := False;
  AEntry.Key := '';
  AEntry.ExpiresAt := 0;

  if not TryDecodeKey(AEncodedKey, AEntry.Key) then
    Exit;
  if (AEntry.Key = '') or (Length(AEntry.Key) > MAX_REPLAY_PROVIDER_KEY_LENGTH) then
    Exit;

  try
    LStream := FsOpen(AFileName, [fmRead]);
    try
      LStream.Read(LVersion, SizeOf(Integer));
      if LVersion <> FREEPASCAL_DIRECTORY_REPLAY_STORE_VERSION then
        Exit(False);

      LStream.Read(AEntry.ExpiresAt, SizeOf(TDateTime));
      if LStream.Position <> LStream.Size then
        Exit(False);

      Result := True;
    finally
    end;
  except
    Result := False;
  end;
end;

function TFreePascalDirectoryEarlyDataReplayStore.AcquireUpdateGuard(
  out AGuard: IFreePascalEarlyDataReplayStoreGuard
): Boolean;
var
  LLockHandle: TPlatformFileHandle;
begin
  Result := False;
  AGuard := nil;
  LLockHandle := PLATFORM_FILE_INVALID_HANDLE;

  if FDirectoryName = '' then
    Exit;

  EnterCriticalSection(GReplayDirectoryStoreLock);
  if not AcquireStoreLock(LLockHandle) then
  begin
    LeaveCriticalSection(GReplayDirectoryStoreLock);
    Exit;
  end;

  try
    AGuard := TFreePascalDirectoryEarlyDataReplayStoreGuard.Create(Self, LLockHandle);
    Result := AGuard <> nil;
  except
    ReleaseStoreLock(LLockHandle);
    LeaveCriticalSection(GReplayDirectoryStoreLock);
    raise;
  end;
end;

function TFreePascalDirectoryEarlyDataReplayStore.LoadEntries(
  out AEntries: TFreePascalEarlyDataReplayStoreEntries
): Boolean;
var
  LReadableDirectoryName: string;
begin
  Result := False;
  SetLength(AEntries, 0);

  if not ResolveReadableDirectoryName(LReadableDirectoryName) then
    Exit;
  if LReadableDirectoryName = '' then
    Exit(True);
  Result := LoadEntriesFromDirectory(LReadableDirectoryName, AEntries);
end;

function TFreePascalDirectoryEarlyDataReplayStore.SaveEntries(
  const AEntries: TFreePascalEarlyDataReplayStoreEntries
): Boolean;
var
  LTempDirectoryName: string;
  LBackupDirectoryName: string;
  LParentDirectory: string;
begin
  Result := False;

  if FDirectoryName = '' then
    Exit;
  if Length(AEntries) > MAX_REPLAY_PROVIDER_ENTRY_COUNT then
    Exit;

  LParentDirectory := nextpas.core.fs.PathDir(FDirectoryName);
  if (LParentDirectory <> '') and (not nextpas.core.fs.MkdirAll(LParentDirectory)) then
    Exit;

  LTempDirectoryName := GetTempDirectoryName;
  LBackupDirectoryName := GetBackupDirectoryName;
  if PathExistsAt(LTempDirectoryName) then
  begin
    if not nextpas.core.fs.IsDir(LTempDirectoryName) then
      Exit(False);
    if not RemovePathTree(LTempDirectoryName) then
      Exit(False);
  end;
  if PathExistsAt(LBackupDirectoryName) then
  begin
    if not nextpas.core.fs.IsDir(LBackupDirectoryName) then
      Exit(False);
    if not RemovePathTree(LBackupDirectoryName) then
      Exit(False);
  end;

  if Length(AEntries) = 0 then
  begin
    if PathExistsAt(FDirectoryName) then
      Result := RemovePathTree(FDirectoryName)
    else
      Result := True;
    Exit;
  end;

  try
    if not WriteSnapshotDirectory(LTempDirectoryName, AEntries) then
      Exit(False);

    if PathExistsAt(FDirectoryName) then
    begin
      if not RenamePathAt(FDirectoryName, LBackupDirectoryName) then
        Exit(False);

      if not RenamePathAt(LTempDirectoryName, FDirectoryName) then
      begin
        RenamePathAt(LBackupDirectoryName, FDirectoryName);
        Exit(False);
      end;

      if PathExistsAt(LBackupDirectoryName) then
        RemovePathTree(LBackupDirectoryName);
    end
    else if not RenamePathAt(LTempDirectoryName, FDirectoryName) then
      Exit(False);

    Result := True;
  finally
    if (not Result) and PathExistsAt(LTempDirectoryName) then
      RemovePathTree(LTempDirectoryName);
  end;
end;

initialization
  InitCriticalSection(GReplayDirectoryStoreLock);

finalization
  DoneCriticalSection(GReplayDirectoryStoreLock);

end.
