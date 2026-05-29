{**
 * Unit: nextpas.core.tls.freepascal.earlydatareplay.dirstore
 * Purpose: FreePascal early-data anti-replay 的目录型本地 store prototype
 *}

unit nextpas.core.tls.freepascal.earlydatareplay.dirstore;

{$mode ObjFPC}{$H+}
{$NOTES OFF} // Suppress false-positive notes for vars passed to untyped params

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.freepascal.session;

type
  TFreePascalDirectoryEarlyDataReplayStore = class;

  TFreePascalDirectoryEarlyDataReplayStoreGuard = class(TInterfacedObject,
    IFreePascalEarlyDataReplayStoreGuard)
  private
    FOwner: TFreePascalDirectoryEarlyDataReplayStore;
    FLockStream: TFileStream;
  public
    constructor Create(
      AOwner: TFreePascalDirectoryEarlyDataReplayStore;
      ALockStream: TFileStream
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
    function OpenLockFileStream(out ALockStream: TFileStream): Boolean;
    function AcquireStoreLock(out ALockStream: TFileStream): Boolean;
    procedure ReleaseStoreLock(var ALockStream: TFileStream);
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

{$IFDEF UNIX}
uses
  Unix;
{$ENDIF}

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

constructor TFreePascalDirectoryEarlyDataReplayStoreGuard.Create(
  AOwner: TFreePascalDirectoryEarlyDataReplayStore;
  ALockStream: TFileStream
);
begin
  inherited Create;
  FOwner := AOwner;
  FLockStream := ALockStream;
end;

destructor TFreePascalDirectoryEarlyDataReplayStoreGuard.Destroy;
begin
  if FOwner <> nil then
    FOwner.ReleaseStoreLock(FLockStream)
  else if FLockStream <> nil then
  begin
    FLockStream.Free;
    FLockStream := nil;
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
  Result := (APath <> '') and (FileExists(APath) or DirectoryExists(APath));
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
    if not DirectoryExists(FDirectoryName) then
      Exit(False);
    ADirectoryName := FDirectoryName;
    Exit(True);
  end;

  LTempDirectoryName := GetTempDirectoryName;
  if PathExistsAt(LTempDirectoryName) then
  begin
    if not DirectoryExists(LTempDirectoryName) then
      Exit(False);
    ADirectoryName := LTempDirectoryName;
    Exit(True);
  end;

  LBackupDirectoryName := GetBackupDirectoryName;
  if PathExistsAt(LBackupDirectoryName) then
  begin
    if not DirectoryExists(LBackupDirectoryName) then
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
  LSearchRec: TSearchRec;
  LEntry: TFreePascalEarlyDataReplayStoreEntry;
  LEntryPath: string;
  LEncodedKey: string;
  LEntryCount: Integer;
begin
  Result := False;
  SetLength(AEntries, 0);

  if ADirectoryName = '' then
    Exit;
  if not DirectoryExists(ADirectoryName) then
    Exit(False);

  LEntryCount := 0;
  if FindFirst(IncludeTrailingPathDelimiter(ADirectoryName) + '*', faAnyFile, LSearchRec) <> 0 then
    Exit(False);

  try
    repeat
      if (LSearchRec.Name = '.') or (LSearchRec.Name = '..') then
        Continue;
      if (LSearchRec.Attr and faDirectory) <> 0 then
        Exit(False);
      if (Length(LSearchRec.Name) <= Length(DIRECTORY_REPLAY_ENTRY_SUFFIX)) or
        (Copy(
            LSearchRec.Name,
            Length(LSearchRec.Name) - Length(DIRECTORY_REPLAY_ENTRY_SUFFIX) + 1,
            Length(DIRECTORY_REPLAY_ENTRY_SUFFIX)
          ) <> DIRECTORY_REPLAY_ENTRY_SUFFIX) then
        Exit(False);

      Inc(LEntryCount);
      if LEntryCount > MAX_REPLAY_PROVIDER_ENTRY_COUNT then
        Exit(False);

      LEncodedKey := Copy(
        LSearchRec.Name,
        1,
        Length(LSearchRec.Name) - Length(DIRECTORY_REPLAY_ENTRY_SUFFIX)
      );
      LEntryPath := IncludeTrailingPathDelimiter(ADirectoryName) + LSearchRec.Name;
      if not TryLoadEntry(LEntryPath, LEncodedKey, LEntry) then
        Exit(False);

      SetLength(AEntries, LEntryCount);
      AEntries[LEntryCount - 1] := LEntry;
    until FindNext(LSearchRec) <> 0;
  finally
    FindClose(LSearchRec);
  end;

  Result := True;
end;

function TFreePascalDirectoryEarlyDataReplayStore.OpenLockFileStream(
  out ALockStream: TFileStream
): Boolean;
var
  LLockFileName: string;
  LDir: string;
  LCreateStream: TFileStream;
  LAttempt: Integer;
begin
  Result := False;
  ALockStream := nil;

  LLockFileName := GetLockFileName;
  if LLockFileName = '' then
    Exit;

  LDir := ExtractFileDir(LLockFileName);
  if (LDir <> '') and (not ForceDirectories(LDir)) then
    Exit;

  for LAttempt := 1 to 2 do
  begin
    try
      ALockStream := TFileStream.Create(LLockFileName, fmOpenReadWrite or fmShareDenyWrite);
      Exit(True);
    except
      if LAttempt = 2 then
        Exit(False);
    end;

    try
      LCreateStream := TFileStream.Create(LLockFileName, fmCreate);
      try
      finally
        LCreateStream.Free;
      end;
    except
      // A concurrent creator may have won the race; the second open attempt decides.
    end;
  end;
end;

function TFreePascalDirectoryEarlyDataReplayStore.AcquireStoreLock(
  out ALockStream: TFileStream
): Boolean;
begin
  Result := False;
  ALockStream := nil;

  if not OpenLockFileStream(ALockStream) then
    Exit;
  {$IFDEF UNIX}
  if FpFlock(ALockStream.Handle, LOCK_EX or LOCK_NB) <> 0 then
  begin
    ALockStream.Free;
    ALockStream := nil;
    Exit(False);
  end;
  {$ENDIF}
  Result := True;
end;

procedure TFreePascalDirectoryEarlyDataReplayStore.ReleaseStoreLock(
  var ALockStream: TFileStream
);
begin
  if ALockStream = nil then
    Exit;
  {$IFDEF UNIX}
  FpFlock(ALockStream.Handle, LOCK_UN);
  {$ENDIF}
  ALockStream.Free;
  ALockStream := nil;
end;

function TFreePascalDirectoryEarlyDataReplayStore.RemovePathTree(
  const APath: string
): Boolean;
var
  LSearchRec: TSearchRec;
  LEntryPath: string;
begin
  Result := False;

  if APath = '' then
    Exit(True);
  if FileExists(APath) then
    Exit(DeleteFile(APath));
  if not DirectoryExists(APath) then
    Exit(True);

  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, LSearchRec) = 0 then
  begin
    repeat
      if (LSearchRec.Name = '.') or (LSearchRec.Name = '..') then
        Continue;

      LEntryPath := IncludeTrailingPathDelimiter(APath) + LSearchRec.Name;
      if not RemovePathTree(LEntryPath) then
      begin
        FindClose(LSearchRec);
        Exit(False);
      end;
    until FindNext(LSearchRec) <> 0;
    FindClose(LSearchRec);
  end;

  Result := RemoveDir(APath);
end;

function TFreePascalDirectoryEarlyDataReplayStore.RenamePathAt(
  const ASourcePath: string;
  const ADestPath: string
): Boolean;
begin
  Result := RenameFile(ASourcePath, ADestPath);
end;

function TFreePascalDirectoryEarlyDataReplayStore.WriteSnapshotDirectory(
  const ADirectoryName: string;
  const AEntries: TFreePascalEarlyDataReplayStoreEntries
): Boolean;
var
  LStream: TFileStream;
  LFileName: string;
  I: Integer;
  LVersion: Integer;
begin
  Result := False;

  if (ADirectoryName = '') or (not ForceDirectories(ADirectoryName)) then
    Exit;

  try
    for I := 0 to High(AEntries) do
    begin
      if (AEntries[I].Key = '') or
        (Length(AEntries[I].Key) > MAX_REPLAY_PROVIDER_KEY_LENGTH) then
        Exit(False);

      LFileName := IncludeTrailingPathDelimiter(ADirectoryName) +
        EncodeKey(AEntries[I].Key) + DIRECTORY_REPLAY_ENTRY_SUFFIX;
      LStream := TFileStream.Create(LFileName, fmCreate);
      try
        LVersion := FREEPASCAL_DIRECTORY_REPLAY_STORE_VERSION;
        LStream.WriteBuffer(LVersion, SizeOf(Integer));
        LStream.WriteBuffer(AEntries[I].ExpiresAt, SizeOf(TDateTime));
      finally
        LStream.Free;
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
  LStream: TFileStream;
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
    LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      LStream.ReadBuffer(LVersion, SizeOf(Integer));
      if LVersion <> FREEPASCAL_DIRECTORY_REPLAY_STORE_VERSION then
        Exit(False);

      LStream.ReadBuffer(AEntry.ExpiresAt, SizeOf(TDateTime));
      if LStream.Position <> LStream.Size then
        Exit(False);

      Result := True;
    finally
      LStream.Free;
    end;
  except
    Result := False;
  end;
end;

function TFreePascalDirectoryEarlyDataReplayStore.AcquireUpdateGuard(
  out AGuard: IFreePascalEarlyDataReplayStoreGuard
): Boolean;
var
  LLockStream: TFileStream;
begin
  Result := False;
  AGuard := nil;
  LLockStream := nil;

  if FDirectoryName = '' then
    Exit;

  EnterCriticalSection(GReplayDirectoryStoreLock);
  if not AcquireStoreLock(LLockStream) then
  begin
    LeaveCriticalSection(GReplayDirectoryStoreLock);
    Exit;
  end;

  try
    AGuard := TFreePascalDirectoryEarlyDataReplayStoreGuard.Create(Self, LLockStream);
    Result := AGuard <> nil;
  except
    ReleaseStoreLock(LLockStream);
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

  LParentDirectory := ExtractFileDir(FDirectoryName);
  if (LParentDirectory <> '') and (not ForceDirectories(LParentDirectory)) then
    Exit;

  LTempDirectoryName := GetTempDirectoryName;
  LBackupDirectoryName := GetBackupDirectoryName;
  if PathExistsAt(LTempDirectoryName) then
  begin
    if not DirectoryExists(LTempDirectoryName) then
      Exit(False);
    if not RemovePathTree(LTempDirectoryName) then
      Exit(False);
  end;
  if PathExistsAt(LBackupDirectoryName) then
  begin
    if not DirectoryExists(LBackupDirectoryName) then
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
