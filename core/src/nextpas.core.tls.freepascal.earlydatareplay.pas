{**
 * Unit: nextpas.core.tls.freepascal.earlydatareplay
 * Purpose: 可替换的 FreePascal early-data anti-replay 默认内存实现
 *}

unit nextpas.core.tls.freepascal.earlydatareplay;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.fs, nextpas.core.text.conv, nextpas.core.time,
  nextpas.core.tls.base,
  nextpas.core.tls.freepascal.context.material,
  nextpas.core.tls.freepascal.session;

type
  // Internal-only managed seam used by the default shared in-memory replay path
  // to keep clear/capacity lifecycle parity after the in-memory ledger was
  // converged onto the store-backed provider flow. File-backed / callback-backed
  // providers are not required to implement this contract.
  IFreePascalManagedReplayStore = interface
    ['{630C6A7B-74C5-45A0-9E84-E78819FE14D7}']
    procedure Clear;
    procedure SetCapacity(ACapacity: Integer);
  end;

  // Internal-only companion seam for managed providers. This currently exists so
  // the default shared in-memory shipped path can forward local enabled/capacity
  // lifecycle changes without widening the public/context surface.
  IFreePascalManagedReplayProvider = interface
    ['{6FE65C91-7F15-4D3C-BB7A-E8A1C50A28B1}']
    procedure Clear;
    procedure SetCapacity(ACapacity: Integer);
  end;

  TFreePascalSharedInMemoryReplayStore = class;

  TFreePascalSharedInMemoryReplayStoreGuard = class(TInterfacedObject,
    IFreePascalEarlyDataReplayStoreGuard)
  private
    FOwner: TFreePascalSharedInMemoryReplayStore;
  public
    constructor Create(AOwner: TFreePascalSharedInMemoryReplayStore);
    destructor Destroy; override;
  end;

  TFreePascalSharedInMemoryReplayStore = class(TInterfacedObject,
    IFreePascalEarlyDataReplayStore,
    IFreePascalManagedReplayStore)
  private
    FEntries: TFreePascalEarlyDataReplayStoreEntries;
    FLock: TRTLCriticalSection;
    FCapacity: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    function AcquireUpdateGuard(
      out AGuard: IFreePascalEarlyDataReplayStoreGuard
    ): Boolean;
    function LoadEntries(
      out AEntries: TFreePascalEarlyDataReplayStoreEntries
    ): Boolean;
    function SaveEntries(
      const AEntries: TFreePascalEarlyDataReplayStoreEntries
    ): Boolean;
    procedure Clear;
    procedure SetCapacity(ACapacity: Integer);
  end;

  TFreePascalReplayProviderAcquireCallback = function(
    const AKey: string;
    AExpiresAt: TDateTime;
    ANow: TDateTime
  ): Boolean of object;

  TFreePascalCallbackEarlyDataReplayProvider = class(TInterfacedObject,
    IFreePascalEarlyDataReplayProvider)
  private
    FOnTryAcquireReplayKey: TFreePascalReplayProviderAcquireCallback;
  public
    constructor Create(ATryAcquireReplayKey: TFreePascalReplayProviderAcquireCallback);

    function TryAcquireReplayKey(
      const AKey: string;
      AExpiresAt: TDateTime;
      ANow: TDateTime
    ): Boolean;
  end;

  TFreePascalStoreBackedEarlyDataReplayProvider = class(TInterfacedObject,
    IFreePascalEarlyDataReplayProvider,
    IFreePascalManagedReplayProvider)
  private
    FStore: IFreePascalEarlyDataReplayStore;

    procedure PruneExpired(
      var AEntries: TFreePascalEarlyDataReplayStoreEntries;
      ANow: TDateTime
    );
  public
    constructor Create(AStore: IFreePascalEarlyDataReplayStore);

    function TryAcquireReplayKey(
      const AKey: string;
      AExpiresAt: TDateTime;
      ANow: TDateTime
    ): Boolean;
    procedure Clear;
    procedure SetCapacity(ACapacity: Integer);
  end;

  TFreePascalDefaultPersistentReplayProvider = class(TInterfacedObject,
    IFreePascalEarlyDataReplayProvider,
    IFreePascalManagedReplayProvider)
  private
    FStore: IFreePascalEarlyDataReplayStore;
    FCapacity: Integer;

    procedure PruneExpired(
      var AEntries: TFreePascalEarlyDataReplayStoreEntries;
      ANow: TDateTime
    );
  public
    constructor Create(AStore: IFreePascalEarlyDataReplayStore);

    function TryAcquireReplayKey(
      const AKey: string;
      AExpiresAt: TDateTime;
      ANow: TDateTime
    ): Boolean;
    procedure Clear;
    procedure SetCapacity(ACapacity: Integer);
  end;

  TFreePascalInMemoryEarlyDataReplayLedger = class(TInterfacedObject,
    IFreePascalManagedEarlyDataReplayLedger)
  private
    // Default shipped wrapper only: retained replay truth now lives in the
    // shared in-memory store-backed path assembled below.
    FDelegate: IFreePascalManagedEarlyDataReplayLedger;
  public
    constructor Create(AEnabled: Boolean; ACapacity: Integer);

    procedure Clear;
    procedure SetEnabled(AEnabled: Boolean);
    procedure SetCapacity(ACapacity: Integer);
    function TryAcquireEarlyDataSession(ASession: ISSLSession): Boolean;
  end;

  TFreePascalDefaultPersistentEarlyDataReplayLedger = class(TInterfacedObject,
    IFreePascalManagedEarlyDataReplayLedger)
  private
    FDelegate: IFreePascalManagedEarlyDataReplayLedger;
  public
    constructor Create(AEnabled: Boolean; ACapacity: Integer);

    procedure Clear;
    procedure SetEnabled(AEnabled: Boolean);
    procedure SetCapacity(ACapacity: Integer);
    function TryAcquireEarlyDataSession(ASession: ISSLSession): Boolean;
  end;

  TFreePascalProviderBackedEarlyDataReplayLedger = class(TInterfacedObject,
    IFreePascalManagedEarlyDataReplayLedger)
  private
    FProvider: IFreePascalEarlyDataReplayProvider;
    FEnabled: Boolean;
    FCapacity: Integer;

    function TryResolveReplayEntry(
      ASession: ISSLSession;
      out AKey: string;
      out AExpiresAt: TDateTime
    ): Boolean;
  public
    constructor Create(
      AProvider: IFreePascalEarlyDataReplayProvider;
      AEnabled: Boolean;
      ACapacity: Integer
    );

    procedure Clear;
    procedure SetEnabled(AEnabled: Boolean);
    procedure SetCapacity(ACapacity: Integer);
    function TryAcquireEarlyDataSession(ASession: ISSLSession): Boolean;
  end;

function InstallReplayProviderBackedLedger(
  AContext: ISSLContext;
  AProvider: IFreePascalEarlyDataReplayProvider
): Boolean;

function InstallCallbackBackedReplayLedger(
  AContext: ISSLContext;
  ATryAcquireReplayKey: TFreePascalReplayProviderAcquireCallback
): Boolean;

function InstallStoreBackedReplayLedger(
  AContext: ISSLContext;
  AStore: IFreePascalEarlyDataReplayStore
): Boolean;

function GetDefaultFreePascalEarlyDataReplayStoreDirectory: string;
procedure SetDefaultFreePascalEarlyDataReplayStoreDirectoryForTesting(
  const ADirectoryName: string
);
procedure ResetDefaultFreePascalEarlyDataReplayStoreDirectoryForTesting;

implementation

uses
  nextpas.core.tls.freepascal.earlydatareplay.dirstore;

const
  FREEPASCAL_DEFAULT_EARLY_DATA_REPLAY_STORE_ENV =
    'FAFAFA_SSL_FREEPASCAL_EARLY_DATA_REPLAY_STORE_DIR';

var
  GDefaultReplayStoreDirectoryOverride: string = '';

function TicketBytesToHex(const ATicket: TBytes): string;
const
  HEX_DIGITS: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, Length(ATicket) * 2);
  for I := 0 to High(ATicket) do
  begin
    Result[I * 2 + 1] := HEX_DIGITS[(ATicket[I] shr 4) and $0F];
    Result[I * 2 + 2] := HEX_DIGITS[ATicket[I] and $0F];
  end;
end;

procedure CopyReplayStoreEntries(
  const ASource: TFreePascalEarlyDataReplayStoreEntries;
  out ADest: TFreePascalEarlyDataReplayStoreEntries
);
var
  I: Integer;
begin
  SetLength(ADest, Length(ASource));
  for I := 0 to High(ASource) do
    ADest[I] := ASource[I];
end;

procedure EnforceReplayStoreCapacity(
  var AEntries: TFreePascalEarlyDataReplayStoreEntries;
  ACapacity: Integer
);
var
  I: Integer;
  LOverflow: Integer;
begin
  if ACapacity <= 0 then
  begin
    SetLength(AEntries, 0);
    Exit;
  end;

  if Length(AEntries) <= ACapacity then
    Exit;

  LOverflow := Length(AEntries) - ACapacity;
  for I := 0 to ACapacity - 1 do
    AEntries[I] := AEntries[I + LOverflow];
  SetLength(AEntries, ACapacity);
end;

function NormalizeReplayStoreDirectory(const ADirectoryName: string): string;
var
  LValue: string;
begin
  LValue := Trim(ADirectoryName);
  if LValue = '' then
    Exit('');
  Result := nextpas.core.fs.PathTrimSep(nextpas.core.fs.PathAbs(LValue));
end;

function GetDefaultFreePascalEarlyDataReplayStoreDirectory: string;
var
  LBaseDirectory: string;
  LHomeDirectory: string;
begin
  if GDefaultReplayStoreDirectoryOverride <> '' then
    Exit(GDefaultReplayStoreDirectoryOverride);

  LBaseDirectory := Trim(
    nextpas.core.fs.GetEnv(FREEPASCAL_DEFAULT_EARLY_DATA_REPLAY_STORE_ENV)
  );
  if LBaseDirectory <> '' then
    Exit(NormalizeReplayStoreDirectory(LBaseDirectory));

  {$IFDEF WINDOWS}
  LBaseDirectory := Trim(nextpas.core.fs.GetEnv('LOCALAPPDATA'));
  if LBaseDirectory = '' then
    LBaseDirectory := Trim(nextpas.core.fs.GetEnv('APPDATA'));
  {$ELSE}
  LBaseDirectory := Trim(nextpas.core.fs.GetEnv('XDG_STATE_HOME'));
  if LBaseDirectory = '' then
  begin
    LHomeDirectory := Trim(nextpas.core.fs.GetEnv('HOME'));
    if LHomeDirectory <> '' then
      LBaseDirectory := nextpas.core.fs.PathJoin([
        nextpas.core.fs.PathAbs(LHomeDirectory),
        '.local',
        'state'
      ]);
  end;
  {$ENDIF}

  if LBaseDirectory = '' then
    LBaseDirectory := nextpas.core.fs.GetTempDir;

  LBaseDirectory := NormalizeReplayStoreDirectory(LBaseDirectory);
  Result := nextpas.core.fs.PathJoin([
    LBaseDirectory,
    'fafafa.ssl',
    'freepascal',
    'early-data-replay'
  ]);
end;

procedure SetDefaultFreePascalEarlyDataReplayStoreDirectoryForTesting(
  const ADirectoryName: string
);
begin
  GDefaultReplayStoreDirectoryOverride := NormalizeReplayStoreDirectory(
    ADirectoryName
  );
end;

procedure ResetDefaultFreePascalEarlyDataReplayStoreDirectoryForTesting;
begin
  GDefaultReplayStoreDirectoryOverride := '';
end;

constructor TFreePascalSharedInMemoryReplayStoreGuard.Create(
  AOwner: TFreePascalSharedInMemoryReplayStore
);
begin
  inherited Create;
  FOwner := AOwner;
end;

destructor TFreePascalSharedInMemoryReplayStoreGuard.Destroy;
begin
  if FOwner <> nil then
  begin
    LeaveCriticalSection(FOwner.FLock);
    FOwner := nil;
  end;
  inherited Destroy;
end;

constructor TFreePascalSharedInMemoryReplayStore.Create;
begin
  inherited Create;
  SetLength(FEntries, 0);
  FCapacity := High(Integer);
  InitCriticalSection(FLock);
end;

destructor TFreePascalSharedInMemoryReplayStore.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

function TFreePascalSharedInMemoryReplayStore.AcquireUpdateGuard(
  out AGuard: IFreePascalEarlyDataReplayStoreGuard
): Boolean;
begin
  Result := False;
  AGuard := nil;

  EnterCriticalSection(FLock);
  try
    AGuard := TFreePascalSharedInMemoryReplayStoreGuard.Create(Self);
    Result := AGuard <> nil;
  except
    LeaveCriticalSection(FLock);
    raise;
  end;
end;

function TFreePascalSharedInMemoryReplayStore.LoadEntries(
  out AEntries: TFreePascalEarlyDataReplayStoreEntries
): Boolean;
begin
  CopyReplayStoreEntries(FEntries, AEntries);
  Result := True;
end;

function TFreePascalSharedInMemoryReplayStore.SaveEntries(
  const AEntries: TFreePascalEarlyDataReplayStoreEntries
): Boolean;
begin
  CopyReplayStoreEntries(AEntries, FEntries);
  EnforceReplayStoreCapacity(FEntries, FCapacity);
  Result := True;
end;

procedure TFreePascalSharedInMemoryReplayStore.Clear;
begin
  EnterCriticalSection(FLock);
  try
    SetLength(FEntries, 0);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TFreePascalSharedInMemoryReplayStore.SetCapacity(ACapacity: Integer);
begin
  if ACapacity < 0 then
    ACapacity := 0;

  EnterCriticalSection(FLock);
  try
    FCapacity := ACapacity;
    EnforceReplayStoreCapacity(FEntries, FCapacity);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

constructor TFreePascalCallbackEarlyDataReplayProvider.Create(
  ATryAcquireReplayKey: TFreePascalReplayProviderAcquireCallback
);
begin
  inherited Create;
  FOnTryAcquireReplayKey := ATryAcquireReplayKey;
end;

function TFreePascalCallbackEarlyDataReplayProvider.TryAcquireReplayKey(
  const AKey: string;
  AExpiresAt: TDateTime;
  ANow: TDateTime
): Boolean;
begin
  Result := Assigned(FOnTryAcquireReplayKey) and
    FOnTryAcquireReplayKey(AKey, AExpiresAt, ANow);
end;

constructor TFreePascalStoreBackedEarlyDataReplayProvider.Create(
  AStore: IFreePascalEarlyDataReplayStore
);
begin
  inherited Create;
  FStore := AStore;
end;

procedure TFreePascalStoreBackedEarlyDataReplayProvider.PruneExpired(
  var AEntries: TFreePascalEarlyDataReplayStoreEntries;
  ANow: TDateTime
);
var
  I: Integer;
  LWriteIndex: Integer;
begin
  LWriteIndex := 0;
  for I := 0 to High(AEntries) do
    if (AEntries[I].Key <> '') and
      ((AEntries[I].ExpiresAt <= 0) or (AEntries[I].ExpiresAt > ANow)) then
    begin
      if LWriteIndex <> I then
        AEntries[LWriteIndex] := AEntries[I];
      Inc(LWriteIndex);
    end;
  SetLength(AEntries, LWriteIndex);
end;

function TFreePascalStoreBackedEarlyDataReplayProvider.TryAcquireReplayKey(
  const AKey: string;
  AExpiresAt: TDateTime;
  ANow: TDateTime
): Boolean;
var
  LEntries: TFreePascalEarlyDataReplayStoreEntries;
  LGuard: IFreePascalEarlyDataReplayStoreGuard;
  I: Integer;
begin
  Result := False;

  if (FStore = nil) or (AKey = '') then
    Exit;
  if (AExpiresAt > 0) and (AExpiresAt <= ANow) then
    Exit;

  try
    if not FStore.AcquireUpdateGuard(LGuard) then
      Exit;
    if LGuard = nil then
      Exit;

    if not FStore.LoadEntries(LEntries) then
      Exit;

    PruneExpired(LEntries, ANow);
    for I := 0 to High(LEntries) do
      if LEntries[I].Key = AKey then
        Exit;

    SetLength(LEntries, Length(LEntries) + 1);
    LEntries[High(LEntries)].Key := AKey;
    LEntries[High(LEntries)].ExpiresAt := AExpiresAt;

    Result := FStore.SaveEntries(LEntries);
  except
    Result := False;
  end;
end;

procedure TFreePascalStoreBackedEarlyDataReplayProvider.Clear;
var
  LManagedStore: IFreePascalManagedReplayStore;
begin
  if Supports(FStore, IFreePascalManagedReplayStore, LManagedStore) then
    LManagedStore.Clear;
end;

procedure TFreePascalStoreBackedEarlyDataReplayProvider.SetCapacity(
  ACapacity: Integer
);
var
  LManagedStore: IFreePascalManagedReplayStore;
begin
  if Supports(FStore, IFreePascalManagedReplayStore, LManagedStore) then
    LManagedStore.SetCapacity(ACapacity);
end;

constructor TFreePascalDefaultPersistentReplayProvider.Create(
  AStore: IFreePascalEarlyDataReplayStore
);
begin
  inherited Create;
  FStore := AStore;
  FCapacity := High(Integer);
end;

procedure TFreePascalDefaultPersistentReplayProvider.PruneExpired(
  var AEntries: TFreePascalEarlyDataReplayStoreEntries;
  ANow: TDateTime
);
var
  I: Integer;
  LWriteIndex: Integer;
begin
  LWriteIndex := 0;
  for I := 0 to High(AEntries) do
    if (AEntries[I].Key <> '') and
      ((AEntries[I].ExpiresAt <= 0) or (AEntries[I].ExpiresAt > ANow)) then
    begin
      if LWriteIndex <> I then
        AEntries[LWriteIndex] := AEntries[I];
      Inc(LWriteIndex);
    end;
  SetLength(AEntries, LWriteIndex);
end;

function TFreePascalDefaultPersistentReplayProvider.TryAcquireReplayKey(
  const AKey: string;
  AExpiresAt: TDateTime;
  ANow: TDateTime
): Boolean;
var
  LEntries: TFreePascalEarlyDataReplayStoreEntries;
  LGuard: IFreePascalEarlyDataReplayStoreGuard;
  I: Integer;
begin
  Result := False;

  if (FStore = nil) or (AKey = '') then
    Exit;
  if (AExpiresAt > 0) and (AExpiresAt <= ANow) then
    Exit;

  try
    if not FStore.AcquireUpdateGuard(LGuard) then
      Exit;
    if LGuard = nil then
      Exit;
    if not FStore.LoadEntries(LEntries) then
      Exit;

    PruneExpired(LEntries, ANow);
    for I := 0 to High(LEntries) do
      if LEntries[I].Key = AKey then
        Exit;

    SetLength(LEntries, Length(LEntries) + 1);
    LEntries[High(LEntries)].Key := AKey;
    LEntries[High(LEntries)].ExpiresAt := AExpiresAt;
    EnforceReplayStoreCapacity(LEntries, FCapacity);

    Result := FStore.SaveEntries(LEntries);
  except
    Result := False;
  end;
end;

procedure TFreePascalDefaultPersistentReplayProvider.Clear;
var
  LEntries: TFreePascalEarlyDataReplayStoreEntries;
  LGuard: IFreePascalEarlyDataReplayStoreGuard;
begin
  if FStore = nil then
    Exit;

  try
    if not FStore.AcquireUpdateGuard(LGuard) then
      Exit;
    if LGuard = nil then
      Exit;
    SetLength(LEntries, 0);
    FStore.SaveEntries(LEntries);
  except
    // fail-closed: ledger-local enable/capacity gates remain authoritative
  end;
end;

procedure TFreePascalDefaultPersistentReplayProvider.SetCapacity(
  ACapacity: Integer
);
var
  LEntries: TFreePascalEarlyDataReplayStoreEntries;
  LGuard: IFreePascalEarlyDataReplayStoreGuard;
begin
  if ACapacity < 0 then
    ACapacity := 0;
  FCapacity := ACapacity;

  if FStore = nil then
    Exit;

  try
    if not FStore.AcquireUpdateGuard(LGuard) then
      Exit;
    if LGuard = nil then
      Exit;
    if not FStore.LoadEntries(LEntries) then
      Exit;
    EnforceReplayStoreCapacity(LEntries, FCapacity);
    FStore.SaveEntries(LEntries);
  except
    // fail-closed: future acquires still observe the ledger-local capacity gate
  end;
end;

constructor TFreePascalInMemoryEarlyDataReplayLedger.Create(
  AEnabled: Boolean;
  ACapacity: Integer
);
var
  LStore: IFreePascalEarlyDataReplayStore;
  LProvider: IFreePascalEarlyDataReplayProvider;
begin
  inherited Create;
  LStore := TFreePascalSharedInMemoryReplayStore.Create;
  LProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(LStore);
  FDelegate := TFreePascalProviderBackedEarlyDataReplayLedger.Create(
    LProvider,
    AEnabled,
    ACapacity
  );
end;

procedure TFreePascalInMemoryEarlyDataReplayLedger.Clear;
begin
  if FDelegate <> nil then
    FDelegate.Clear;
end;

procedure TFreePascalInMemoryEarlyDataReplayLedger.SetEnabled(AEnabled: Boolean);
begin
  if FDelegate <> nil then
    FDelegate.SetEnabled(AEnabled);
end;

procedure TFreePascalInMemoryEarlyDataReplayLedger.SetCapacity(ACapacity: Integer);
begin
  if FDelegate <> nil then
    FDelegate.SetCapacity(ACapacity);
end;

function TFreePascalInMemoryEarlyDataReplayLedger.TryAcquireEarlyDataSession(
  ASession: ISSLSession
): Boolean;
begin
  Result := Assigned(FDelegate) and FDelegate.TryAcquireEarlyDataSession(ASession);
end;

constructor TFreePascalDefaultPersistentEarlyDataReplayLedger.Create(
  AEnabled: Boolean;
  ACapacity: Integer
);
var
  LStore: IFreePascalEarlyDataReplayStore;
  LProvider: IFreePascalEarlyDataReplayProvider;
begin
  inherited Create;
  LStore := TFreePascalDirectoryEarlyDataReplayStore.Create(
    GetDefaultFreePascalEarlyDataReplayStoreDirectory
  );
  LProvider := TFreePascalDefaultPersistentReplayProvider.Create(LStore);
  FDelegate := TFreePascalProviderBackedEarlyDataReplayLedger.Create(
    LProvider,
    AEnabled,
    ACapacity
  );
end;

procedure TFreePascalDefaultPersistentEarlyDataReplayLedger.Clear;
begin
  if FDelegate <> nil then
    FDelegate.Clear;
end;

procedure TFreePascalDefaultPersistentEarlyDataReplayLedger.SetEnabled(
  AEnabled: Boolean
);
begin
  if FDelegate <> nil then
    FDelegate.SetEnabled(AEnabled);
end;

procedure TFreePascalDefaultPersistentEarlyDataReplayLedger.SetCapacity(
  ACapacity: Integer
);
begin
  if FDelegate <> nil then
    FDelegate.SetCapacity(ACapacity);
end;

function TFreePascalDefaultPersistentEarlyDataReplayLedger.TryAcquireEarlyDataSession(
  ASession: ISSLSession
): Boolean;
begin
  Result := Assigned(FDelegate) and FDelegate.TryAcquireEarlyDataSession(
    ASession
  );
end;

constructor TFreePascalProviderBackedEarlyDataReplayLedger.Create(
  AProvider: IFreePascalEarlyDataReplayProvider;
  AEnabled: Boolean;
  ACapacity: Integer
);
begin
  inherited Create;
  FProvider := AProvider;
  FEnabled := True;
  FCapacity := High(Integer);
  SetCapacity(ACapacity);
  SetEnabled(AEnabled);
end;

function TFreePascalProviderBackedEarlyDataReplayLedger.TryResolveReplayEntry(
  ASession: ISSLSession;
  out AKey: string;
  out AExpiresAt: TDateTime
): Boolean;
var
  LResumptionSession: IFreePascalResumptionSession;
  LEffectiveTimeout: Integer;
begin
  Result := False;
  AKey := '';
  AExpiresAt := 0;

  if ASession = nil then
    Exit;
  if not ASession.IsValid then
    Exit;
  if not ASession.IsResumable then
    Exit;
  if not Supports(ASession, IFreePascalResumptionSession, LResumptionSession) then
    Exit;

  AKey := TicketBytesToHex(LResumptionSession.GetTicket);
  if AKey = '' then
    Exit;

  LEffectiveTimeout := ASession.GetTimeout;
  if (LResumptionSession.GetTicketLifetime > 0) and
    ((LEffectiveTimeout <= 0) or
      (Integer(LResumptionSession.GetTicketLifetime) < LEffectiveTimeout)) then
    LEffectiveTimeout := Integer(LResumptionSession.GetTicketLifetime);

  if LEffectiveTimeout > 0 then
    AExpiresAt := IncSecond(ASession.GetCreationTime, LEffectiveTimeout);

  Result := True;
end;

procedure TFreePascalProviderBackedEarlyDataReplayLedger.Clear;
var
  LManagedProvider: IFreePascalManagedReplayProvider;
begin
  if Supports(FProvider, IFreePascalManagedReplayProvider, LManagedProvider) then
    try
      LManagedProvider.Clear;
    except
      // Deliberate swallow boundary: runtime/handshake callers keep the local
      // enabled/capacity gate as the authoritative fail-closed control even if
      // a managed provider hook cannot complete.
    end;
end;

procedure TFreePascalProviderBackedEarlyDataReplayLedger.SetEnabled(
  AEnabled: Boolean
);
begin
  FEnabled := AEnabled;
  if not AEnabled then
    Clear;
end;

procedure TFreePascalProviderBackedEarlyDataReplayLedger.SetCapacity(
  ACapacity: Integer
);
var
  LManagedProvider: IFreePascalManagedReplayProvider;
begin
  FCapacity := ACapacity;
  if Supports(FProvider, IFreePascalManagedReplayProvider, LManagedProvider) then
    try
      LManagedProvider.SetCapacity(ACapacity);
    except
      // Deliberate swallow boundary: preserve the ledger-local gate decision and
      // avoid surfacing managed hook failures into the early-data runtime path.
    end;
  if ACapacity <= 0 then
    Clear;
end;

function TFreePascalProviderBackedEarlyDataReplayLedger.TryAcquireEarlyDataSession(
  ASession: ISSLSession
): Boolean;
var
  LKey: string;
  LExpiresAt: TDateTime;
begin
  Result := False;
  if (not FEnabled) or (FCapacity <= 0) or (FProvider = nil) then
    Exit;
  if not TryResolveReplayEntry(ASession, LKey, LExpiresAt) then
    Exit;

  try
    Result := FProvider.TryAcquireReplayKey(LKey, LExpiresAt, nextpas.core.time.DateTimeNow);
  except
    Result := False;
  end;
end;

function InstallReplayProviderBackedLedger(
  AContext: ISSLContext;
  AProvider: IFreePascalEarlyDataReplayProvider
): Boolean;
var
  LInstaller: IFreePascalContextEarlyDataReplayProviderInstaller;
begin
  Result := False;

  if (AContext = nil) or (AProvider = nil) then
    Exit;
  if not Supports(AContext, IFreePascalContextEarlyDataReplayProviderInstaller, LInstaller) then
    Exit;

  try
    Result := LInstaller.InstallReplayProviderBackedLedger(AProvider);
  except
    Result := False;
  end;
end;

function InstallCallbackBackedReplayLedger(
  AContext: ISSLContext;
  ATryAcquireReplayKey: TFreePascalReplayProviderAcquireCallback
): Boolean;
var
  LProvider: IFreePascalEarlyDataReplayProvider;
begin
  Result := False;

  if (AContext = nil) or (not Assigned(ATryAcquireReplayKey)) then
    Exit;

  try
    LProvider := TFreePascalCallbackEarlyDataReplayProvider.Create(
      ATryAcquireReplayKey
    );
    Result := InstallReplayProviderBackedLedger(AContext, LProvider);
  except
    Result := False;
  end;
end;

function InstallStoreBackedReplayLedger(
  AContext: ISSLContext;
  AStore: IFreePascalEarlyDataReplayStore
): Boolean;
var
  LProvider: IFreePascalEarlyDataReplayProvider;
begin
  Result := False;

  if (AContext = nil) or (AStore = nil) then
    Exit;

  try
    LProvider := TFreePascalStoreBackedEarlyDataReplayProvider.Create(AStore);
    Result := InstallReplayProviderBackedLedger(AContext, LProvider);
  except
    Result := False;
  end;
end;

end.
