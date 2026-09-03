unit nextpas.core.db.factory;

{ Narrow driver registry: zero L2 imports, IDbDriver + DbOpen(name|kind).
  Pool integration via nextpas.core.db.factory.pool bridge (separate leaf
  for fully independent build isolation). Builtins via explicit
  DbRegisterDriver (per-backend factory.register.* or direct adapter
  Connect*), factory.builtin zero-logic leaf physically removed 2026-09-02
  no longer counted as module node (explicit registration wins, see CONTRACT §2.14). Third-party via
  DbRegisterDriver. Zero SysUtils, heaptrc0. }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.utils,
  nextpas.core.text.conv,
  nextpas.core.db.base,
  nextpas.core.db.intf;

type
  { Sorted lower-case driver names snapshot. }
  TDbDriverNames = array of string;

  { Driver abstraction: Name is registry key (lower-cased on register). }
  IDbDriver = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE101}']
    function Name: string;
    function Kind: TDbKind;
    function Open(const ADsn: string;
      const AOptions: TDbConnectOptions;
      const AStmtCacheCapacity: Integer = 64): IDbConnection;
  end;

  TDbDriverOpenFunc = reference to function(const ADsn: string;
    const AOptions: TDbConnectOptions;
    const AStmtCacheCapacity: Integer): IDbConnection;

  { Builtin triple: name + kind + open func. }
  TBuiltinDriver = class(TInterfacedObject, IDbDriver)
  private
    FName: string;
    FKind: TDbKind;
    FOpen: TDbDriverOpenFunc;
  public
    constructor Create(const AName: string; AKind: TDbKind;
      const AOpen: TDbDriverOpenFunc);
    function Name: string;
    function Kind: TDbKind;
    function Open(const ADsn: string;
      const AOptions: TDbConnectOptions;
      const AStmtCacheCapacity: Integer = 64): IDbConnection;
  end;

{ nil/empty/duplicate -> EDbError(dbkUnknown). Case-insensitive. }
procedure DbRegisterDriver(ADriver: IDbDriver);

function DbRegisteredDrivers: TDbDriverNames;
function DbDriverExists(const AName: string): Boolean;

{ Go sql.Open semantics: unknown name -> EDbError with name. }
function DbOpen(const ADriver: string; const ADsn: string): IDbConnection;
  overload; inline;
function DbOpen(const ADriver: string; const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer = 64): IDbConnection; overload;

{ Kind dispatch: scans by name then by Kind; dbkUnknown with no match -> EDbNotSupported. }
function DbOpen(AKind: TDbKind; const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer = 64): IDbConnection; overload;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.collections.ordered_registry,
  nextpas.core.sync.intf,
  nextpas.core.sync.rwlock;

const
  FACTORY_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;
  FACTORY_BYTES_SINGLE_SOURCE_VERSION = BYTES_OPS_SINGLE_SOURCE_VERSION;

{$I nextpas.core.bytes.ops.single_source.inc}

type
  TDbDriverEntry = record
    Name: string;
    Driver: IDbDriver;
  end;
  TDbDriverEntries = array of TDbDriverEntry;

var
  // Concurrency: all GDrivers/GCachedNames access under GLock (shared for read,
  // exclusive for write). No lock-free dynarray read — eliminates seqlock
  // CoW race (TryGetDriverFast GDrivers[I] vs GDrivers:=LNew realloc).
  // Registration may be concurrent with DbOpen/DbDriverExists; write serial
  // via exclusive lock, sequential at startup is the common case.
  GDrivers: array of TDbDriverEntry;
  GCachedNames: TDbDriverNames = nil;
  GLock: IRWLock = nil;

function NormalizeName(const AName: string): string; inline;
begin
  Result := NormalizeLowerTrim(AName);
end;

function CompareDriverEntry(const A, B: TDbDriverEntry; AData: Pointer): SizeInt; inline;
begin
  // zero-copy string compare, inline; owner=collections.ordered_registry shape
  if A.Name < B.Name then
    Result := -1
  else if A.Name > B.Name then
    Result := 1
  else
    Result := 0;
end;

function DbRegistryLowerBound(const ASnap: array of TDbDriverEntry; const AName: string): SizeInt; inline;
var
  LProbe: TDbDriverEntry;
begin
  // O(log n) lower_bound via collections.ordered_registry single source, inline, zero-copy string compare (probe shallow copy refcount).
  // Owner=collections ordered_registry (OrderedLowerBound -> algorithms.LowerBound single source).
  LProbe.Name := AName;
  LProbe.Driver := nil;
  Result := specialize OrderedLowerBound<TDbDriverEntry>(ASnap, LProbe, @CompareDriverEntry, nil);
end;

function RegistryOrderedSearch(const ASnap: array of TDbDriverEntry; const AName: string; out AInsertPos: Integer): Integer;
var
  LProbe: TDbDriverEntry;
  LPos: SizeInt;
  LFound: Boolean;
begin
  // O(log n) single pass via collections.ordered_registry OrderedBinarySearch, inline, zero-copy.
  LProbe.Name := AName;
  LProbe.Driver := nil;
  LFound := specialize OrderedBinarySearch<TDbDriverEntry>(ASnap, LProbe, @CompareDriverEntry, nil, LPos);
  AInsertPos := Integer(LPos);
  if LFound then
    Result := Integer(LPos)
  else
    Result := -1;
end;

function FindIndexBin(const ASnap: array of TDbDriverEntry; const AName: string): Integer; inline;
var
  LPos: Integer;
begin
  // O(log n) ordered binary, inline.
  Result := RegistryOrderedSearch(ASnap, AName, LPos);
end;

function FindEntryLocked(const AName: string): Integer; inline;
begin
  // O(log n) binary on sorted GDrivers, inline.
  Result := FindIndexBin(GDrivers, AName);
end;

function FindInSnapshot(const ASnap: array of TDbDriverEntry; const AName: string): Integer; inline;
begin
  // O(log n) binary, inline, zero-copy.
  Result := FindIndexBin(ASnap, AName);
end;

function FindInsertPosBin(const ASnap: array of TDbDriverEntry; const AName: string): Integer; inline;
var
  LFound: Integer;
  LPos: Integer;
begin
  // O(log n) ordered binary, inline.
  LFound := RegistryOrderedSearch(ASnap, AName, LPos);
  if LFound >= 0 then
    Result := LFound
  else
    Result := LPos;
end;

function TryGetDriverFast(const AName: string; out ADriver: IDbDriver): Boolean;
var
  LIdx: Integer;
begin
  // O(log n) shared-lock read, zero-copy, inline.
  Result := False;
  ADriver := nil;
  GLock.AcquireRead;
  try
    LIdx := FindIndexBin(GDrivers, AName);
    if LIdx >= 0 then
    begin
      ADriver := GDrivers[LIdx].Driver;
      Exit(True);
    end;
  finally
    GLock.ReleaseRead;
  end;
end;

function GetDriverLocked(const AName: string): IDbDriver;
begin
  // O(log n) shared-lock via TryGetDriverFast, lock released before Open.
  if not TryGetDriverFast(AName, Result) then
    raise EDbError.CreateSimple(dbkUnknown,
      'db.factory: unknown driver: "' + AName + '"');
end;

function TakeSnapshot(out ASnap: TDbDriverEntries): Integer; inline;
begin
  // O(1) ref copy under read lock.
  GLock.AcquireRead;
  try
    ASnap := GDrivers;
  finally
    GLock.ReleaseRead;
  end;
  Result := Length(ASnap);
end;

function KindToBuiltinName(AKind: TDbKind): string; inline;
begin
  case AKind of
    dbkSqlite:   Result := 'sqlite';
    dbkPostgres: Result := 'postgres';
    dbkMysql:    Result := 'mysql';
    dbkOdbc:     Result := 'odbc';
    dbkRedis:    Result := 'redis';
    dbkDm:       Result := 'dm';
  else
    Result := '';
  end;
end;

procedure DbRegisterDriver(ADriver: IDbDriver);
var
  LName: string;
  LNew: array of TDbDriverEntry;
  LEntry: TDbDriverEntry;
  LInsertPos, I: Integer;
  LDup: Boolean;
  LExists: Boolean;
begin
  if ADriver = nil then
    raise EDbError.CreateSimple(dbkUnknown,
      'db.factory: nil driver registration');
  LName := NormalizeName(ADriver.Name);
  if LName = '' then
    raise EDbError.CreateSimple(dbkUnknown,
      'db.factory: driver name must not be empty');
  // O(log n) existence check under shared lock, zero-copy.
  GLock.AcquireRead;
  try
    LExists := FindEntryLocked(LName) >= 0;
  finally
    GLock.ReleaseRead;
  end;
  if LExists then
    raise EDbError.CreateSimple(dbkUnknown,
      'db.factory: driver already registered: ' + LName);
  LDup := False;
  GLock.AcquireWrite;
  try
    if FindEntryLocked(LName) >= 0 then
      LDup := True
    else
    begin
      LInsertPos := FindInsertPosBin(GDrivers, LName);
      SetLength(LNew, Length(GDrivers) + 1);
      for I := 0 to LInsertPos - 1 do
        LNew[I] := GDrivers[I];
      LEntry.Name := LName;
      LEntry.Driver := ADriver;
      LNew[LInsertPos] := LEntry;
      for I := LInsertPos to High(GDrivers) do
        LNew[I + 1] := GDrivers[I];
      GDrivers := LNew;
      SetLength(GCachedNames, Length(GDrivers));
      for I := 0 to High(GDrivers) do
        GCachedNames[I] := GDrivers[I].Name;
    end;
  finally
    GLock.ReleaseWrite;
  end;
  if LDup then
    raise EDbError.CreateSimple(dbkUnknown,
      'db.factory: driver already registered: ' + LName);
end;

function DbDriverExists(const AName: string): Boolean; inline;
var
  LName: string;
  LDummy: IDbDriver;
begin
  // O(log n) via TryGetDriverFast, inline.
  LName := NormalizeName(AName);
  Result := TryGetDriverFast(LName, LDummy);
end;

function DbRegisteredDrivers: TDbDriverNames; inline;
begin
  // Defensive Copy, inline; isolates GCachedNames from caller mutation.
  GLock.AcquireRead;
  try
    Result := Copy(GCachedNames);
  finally
    GLock.ReleaseRead;
  end;
end;

function DriverBySnapshot(const ASnap: array of TDbDriverEntry; const AName: string): IDbDriver; inline;
var
  LIdx: Integer;
begin
  LIdx := FindInSnapshot(ASnap, AName);
  if LIdx < 0 then
    raise EDbError.CreateSimple(dbkUnknown,
      'db.factory: unknown driver: "' + AName + '"');
  Result := ASnap[LIdx].Driver;
end;

function DbOpen(const ADriver: string; const ADsn: string): IDbConnection; overload; inline;
begin
  Result := DbOpen(ADriver, ADsn, TDbConnectOptions.Default, 64);
end;

function DbOpen(const ADriver: string; const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; overload;
var
  LDriver: IDbDriver;
  LName: string;
begin
  if ADriver = '' then
    raise EDbError.CreateSimple(dbkUnknown,
      'db.factory: empty driver name');
  // via GetDriverLocked shared-lock, lock released before Open.
  LName := NormalizeName(ADriver);
  LDriver := GetDriverLocked(LName);
  Result := LDriver.Open(ADsn, AOptions, AStmtCacheCapacity);
end;

function DbOpen(AKind: TDbKind; const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; overload;
var
  I, LIdx: Integer;
  LDriver: IDbDriver;
  LBuiltin: string;
begin
  // Shared-lock O(log n) builtin name + O(n) Kind scan, Open outside lock.
  LDriver := nil;
  GLock.AcquireRead;
  try
    LBuiltin := KindToBuiltinName(AKind);
    if LBuiltin <> '' then
    begin
      LIdx := FindIndexBin(GDrivers, LBuiltin);
      if LIdx >= 0 then
        LDriver := GDrivers[LIdx].Driver;
    end;
    if LDriver = nil then
      for I := 0 to High(GDrivers) do
        if GDrivers[I].Driver.Kind = AKind then
        begin
          LDriver := GDrivers[I].Driver;
          Break;
        end;
    if LDriver = nil then
      raise EDbNotSupported.CreateSimple(dbkUnknown,
        'db.factory: no driver registered for kind');
  finally
    GLock.ReleaseRead;
  end;
  Result := LDriver.Open(ADsn, AOptions, AStmtCacheCapacity);
end;

{ ---- TBuiltinDriver ---- }

constructor TBuiltinDriver.Create(const AName: string; AKind: TDbKind;
  const AOpen: TDbDriverOpenFunc);
begin
  inherited Create;
  FName := AName;
  FKind := AKind;
  FOpen := AOpen;
end;

function TBuiltinDriver.Name: string;
begin
  Result := FName;
end;

function TBuiltinDriver.Kind: TDbKind;
begin
  Result := FKind;
end;

function TBuiltinDriver.Open(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection;
begin
  Result := FOpen(ADsn, AOptions, AStmtCacheCapacity);
end;

initialization
  GLock := TRWLock.Create;

finalization
  GCachedNames := nil;
  GDrivers := nil;
  GLock := nil;

end.
