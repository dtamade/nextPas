unit nextpas.core.http.impl.h2.client.pool;
{**
 * @desc H2 client idle-connection pool (STRUCT-opt extract from impl.h2.client).
 *       Lock discipline: never Close/probe while holding the pool lock.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync;

type
  { Owned H2 client connection surface required by the idle pool.
    Concrete type is TH2ClientConnection in impl.h2.client. }
  TH2PooledClientConnection = class(TInterfacedObject)
  public
    function IsReusable: Boolean; virtual; abstract;
    function ProbeHealth: Boolean; virtual; abstract;
    procedure Close; virtual; abstract;
  end;

  { Per-authority idle H2 connections. MaxPoolSize is per host key, not global. }
  TH2IdleConnectionPool = class
  private
    FLock: IMutex;
    FEntries: array of record
      Host: string;
      Port: UInt16;
      Secure: Boolean;
      Conn: TH2PooledClientConnection;
      IdleAtMs: UInt64;
    end;
    FCount: Int32;
    FMaxPoolSize: Int32;
    FIdleTTL: Int64;
    function EntryExpired(const AIndex: Int32): Boolean;
    procedure RemoveAt(const AIndex: Int32);
    procedure CloseAndFree(const AConn: TH2PooledClientConnection);
  public
    constructor Create(const AMaxPoolSize: Int32; const AIdleTTL: Int64);
    destructor Destroy; override;
    function Get(const AHost: string; const APort: UInt16;
      const ASecure: Boolean): TH2PooledClientConnection;
    procedure Put(const AHost: string; const APort: UInt16;
      const ASecure: Boolean; const AConn: TH2PooledClientConnection);
    procedure Clear;
  end;

{ Host key for pool authority matching (case-folded). }
function CanonicalPoolHostKey(const AHost: string): string; inline;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.time,
  nextpas.core.text.conv;

const
  { Skip wire PING when the conn was just returned — RoundTripMany / tight
    keep-alive loops were paying a full RTT per batch (H2 peer ~10× gap). }
  H2_POOL_PROBE_GRACE_MS = 1000;

function CanonicalPoolHostKey(const AHost: string): string; inline;
begin
  Result := LowerCase(AHost);
end;

constructor TH2IdleConnectionPool.Create(const AMaxPoolSize: Int32;
  const AIdleTTL: Int64);
begin
  inherited Create;
  FMaxPoolSize := AMaxPoolSize;
  FIdleTTL := AIdleTTL;
  FLock := Mutex;
  FCount := 0;
end;

destructor TH2IdleConnectionPool.Destroy;
begin
  Clear;
  FLock := nil;
  inherited Destroy;
end;

function TH2IdleConnectionPool.EntryExpired(const AIndex: Int32): Boolean;
var
  LNow: UInt64;
  LAge: UInt64;
begin
  Result := False;
  if FIdleTTL <= 0 then
    Exit;
  LNow := GetTickCount64;
  if LNow >= FEntries[AIndex].IdleAtMs then
    LAge := LNow - FEntries[AIndex].IdleAtMs
  else
    LAge := 0;
  Result := LAge >= UInt64(FIdleTTL);
end;

procedure TH2IdleConnectionPool.RemoveAt(const AIndex: Int32);
begin
  if (AIndex < 0) or (AIndex >= FCount) then
    Exit;
  FEntries[AIndex] := FEntries[FCount - 1];
  Dec(FCount);
end;

procedure TH2IdleConnectionPool.CloseAndFree(
  const AConn: TH2PooledClientConnection);
begin
  if AConn = nil then
    Exit;
  try
    AConn.Close;
  except
  end;
  try
    AConn.Free;
  except
  end;
end;

function TH2IdleConnectionPool.Get(const AHost: string; const APort: UInt16;
  const ASecure: Boolean): TH2PooledClientConnection;
var
  LI: Int32;
  LCandidate: TH2PooledClientConnection;
  LToClose: array of TH2PooledClientConnection;
  LCloseCount: Int32;
  LIdleAtMs: UInt64;
  LIdleMs: UInt64;
  LNow: UInt64;
  LNeedProbe: Boolean;
begin
  { Never Close/Free while holding FLock — same hang class as H1 pool. }
  Result := nil;
  LCloseCount := 0;
  SetLength(LToClose, 0);
  while True do
  begin
    LCandidate := nil;
    LIdleAtMs := 0;
    FLock.Acquire;
    try
      LI := 0;
      while LI < FCount do
      begin
        if (FEntries[LI].Host = AHost) and (FEntries[LI].Port = APort) and
           (FEntries[LI].Secure = ASecure) then
        begin
          if EntryExpired(LI) then
          begin
            if FEntries[LI].Conn <> nil then
            begin
              if LCloseCount >= Length(LToClose) then
                SetLength(LToClose, LCloseCount + 4);
              LToClose[LCloseCount] := FEntries[LI].Conn;
              Inc(LCloseCount);
            end;
            RemoveAt(LI);
            Continue;
          end;
          LCandidate := FEntries[LI].Conn;
          LIdleAtMs := FEntries[LI].IdleAtMs;
          RemoveAt(LI);
          Break;
        end;
        Inc(LI);
      end;
    finally
      FLock.Release;
    end;

    if LCandidate = nil then
      Break;

    { Probe outside the pool lock: PING/Read can block (same hang class as Close).
      Fresh idle: only IsReusable (no wire PING). }
    LNeedProbe := True;
    if LIdleAtMs > 0 then
    begin
      LNow := GetTickCount64;
      if LNow >= LIdleAtMs then
        LIdleMs := LNow - LIdleAtMs
      else
        LIdleMs := 0;
      if LIdleMs < H2_POOL_PROBE_GRACE_MS then
        LNeedProbe := False;
    end;
    if LCandidate.IsReusable and
       ((not LNeedProbe) or LCandidate.ProbeHealth) then
    begin
      Result := LCandidate;
      Break;
    end;

    if LCloseCount >= Length(LToClose) then
      SetLength(LToClose, LCloseCount + 4);
    LToClose[LCloseCount] := LCandidate;
    Inc(LCloseCount);
  end;

  for LI := 0 to LCloseCount - 1 do
    CloseAndFree(LToClose[LI]);
end;

procedure TH2IdleConnectionPool.Put(const AHost: string; const APort: UInt16;
  const ASecure: Boolean; const AConn: TH2PooledClientConnection);
var
  LI: Int32;
  LAuthorityIdle: Int32;
  LToClose: array of TH2PooledClientConnection;
  LCloseCount: Int32;
  LReject: Boolean;
begin
  LCloseCount := 0;
  SetLength(LToClose, 0);
  LReject := False;
  FLock.Acquire;
  try
    if (AConn = nil) or (not AConn.IsReusable) then
    begin
      LReject := AConn <> nil;
      Exit;
    end;
    LI := 0;
    while LI < FCount do
    begin
      if (FEntries[LI].Host = AHost) and (FEntries[LI].Port = APort) and
         (FEntries[LI].Secure = ASecure) and EntryExpired(LI) then
      begin
        if FEntries[LI].Conn <> nil then
        begin
          if LCloseCount >= Length(LToClose) then
            SetLength(LToClose, LCloseCount + 4);
          LToClose[LCloseCount] := FEntries[LI].Conn;
          Inc(LCloseCount);
        end;
        RemoveAt(LI);
      end
      else
        Inc(LI);
    end;
    if FMaxPoolSize > 0 then
    begin
      LAuthorityIdle := 0;
      for LI := 0 to FCount - 1 do
        if (FEntries[LI].Host = AHost) and (FEntries[LI].Port = APort) and
           (FEntries[LI].Secure = ASecure) then
          Inc(LAuthorityIdle);
      if LAuthorityIdle >= FMaxPoolSize then
      begin
        LReject := True;
        Exit;
      end;
    end;
    if FCount >= Length(FEntries) then
      SetLength(FEntries, FCount + 4);
    FEntries[FCount].Host := AHost;
    FEntries[FCount].Port := APort;
    FEntries[FCount].Secure := ASecure;
    FEntries[FCount].Conn := AConn;
    FEntries[FCount].IdleAtMs := GetTickCount64;
    Inc(FCount);
  finally
    FLock.Release;
  end;

  if LReject and (AConn <> nil) then
  begin
    if LCloseCount >= Length(LToClose) then
      SetLength(LToClose, LCloseCount + 4);
    LToClose[LCloseCount] := AConn;
    Inc(LCloseCount);
  end;
  for LI := 0 to LCloseCount - 1 do
    CloseAndFree(LToClose[LI]);
end;

procedure TH2IdleConnectionPool.Clear;
var
  LI: Int32;
  LToClose: array of TH2PooledClientConnection;
  LCloseCount: Int32;
begin
  LCloseCount := 0;
  SetLength(LToClose, 0);
  FLock.Acquire;
  try
    for LI := 0 to FCount - 1 do
      if FEntries[LI].Conn <> nil then
      begin
        if LCloseCount >= Length(LToClose) then
          SetLength(LToClose, LCloseCount + 4);
        LToClose[LCloseCount] := FEntries[LI].Conn;
        Inc(LCloseCount);
      end;
    FEntries := nil;
    FCount := 0;
  finally
    FLock.Release;
  end;
  for LI := 0 to LCloseCount - 1 do
    CloseAndFree(LToClose[LI]);
end;

end.