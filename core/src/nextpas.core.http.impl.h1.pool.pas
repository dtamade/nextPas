unit nextpas.core.http.impl.h1.pool;
{**
 * @desc H1 client idle-connection pool (STRUCT-1 extract from impl.h1).
 *       Lock discipline: never Close/probe sockets while holding the pool lock.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.intf,
  nextpas.core.sync;

type
  { Per-authority idle sockets. MaxPoolSize is per host key, not global. }
  TH1IdleConnectionPool = class
  private
    FLock: IMutex;
    FEntries: array of record
      Host: string;
      Port: UInt16;
      Conn: ITcpStream;
      IdleAtMs: UInt64;
    end;
    FCount: Int32;
    FMaxPoolSize: Int32;
    FIdleTTL: Int64;
    function ConnectionIsReusable(const AConn: ITcpStream): Boolean;
    function EntryExpired(const AIndex: Int32): Boolean;
    procedure RemoveAt(const AIndex: Int32);
  public
    constructor Create(const AMaxPoolSize: Int32; const AIdleTTL: Int64);
    destructor Destroy; override;
    function Get(const AHost: string; const APort: UInt16): ITcpStream;
    procedure Put(const AHost: string; const APort: UInt16;
      const AConn: ITcpStream);
    procedure Clear;
  end;

{ Host key for pool authority matching (case-folded). }
function CanonicalPoolHostKey(const AHost: string): string; inline;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.time,
  nextpas.core.time.deadline,
  nextpas.core.time.base,
  nextpas.core.text.conv;

function CanonicalPoolHostKey(const AHost: string): string; inline;
begin
  Result := LowerCase(AHost);
end;

constructor TH1IdleConnectionPool.Create(const AMaxPoolSize: Int32;
  const AIdleTTL: Int64);
begin
  inherited Create;
  FMaxPoolSize := AMaxPoolSize;
  if FMaxPoolSize <= 0 then
    FMaxPoolSize := 64;
  FIdleTTL := AIdleTTL;
  FLock := Mutex;
  FCount := 0;
end;

destructor TH1IdleConnectionPool.Destroy;
begin
  Clear;
  FLock := nil;
  inherited Destroy;
end;

function TH1IdleConnectionPool.ConnectionIsReusable(
  const AConn: ITcpStream): Boolean;
var
  LRuntime: ITcpStreamRuntime;
  LByte: Byte;
  LRead: SizeUInt;
begin
  { Active health probe on borrow: non-blocking peek. WouldBlock =
    idle/live; any data/EOF/error = discard. Must not run under FLock. }
  Result := False;
  if AConn = nil then
    Exit;
  if not Supports(AConn, ITcpStreamRuntime, LRuntime) then
    Exit;

  try
    LRuntime.SetBlocking(False);
    try
      Result := LRuntime.TryRead(LByte, 1, LRead) = tsiorWouldBlock;
    finally
      LRuntime.SetBlocking(True);
    end;
  except
    Result := False;
  end;
end;

function TH1IdleConnectionPool.EntryExpired(const AIndex: Int32): Boolean;
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

procedure TH1IdleConnectionPool.RemoveAt(const AIndex: Int32);
begin
  if (AIndex < 0) or (AIndex >= FCount) then
    Exit;
  FEntries[AIndex] := FEntries[FCount - 1];
  Dec(FCount);
end;

function TH1IdleConnectionPool.Get(const AHost: string;
  const APort: UInt16): ITcpStream;
var
  LI: Int32;
  LCandidate: ITcpStream;
  LToClose: array of ITcpStream;
  LCloseCount: Int32;
begin
  { Never Close or probe sockets while holding FLock: Close/TryRead can
    block or re-enter pool paths and hang the IdleTTL client suite. }
  Result := nil;
  LCloseCount := 0;
  SetLength(LToClose, 0);
  while True do
  begin
    LCandidate := nil;
    FLock.Acquire;
    try
      LI := 0;
      while LI < FCount do
      begin
        if (FEntries[LI].Host = AHost) and (FEntries[LI].Port = APort) then
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

    if ConnectionIsReusable(LCandidate) then
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
    if LToClose[LI] <> nil then
    try
      LToClose[LI].Close;
    except
    end;
end;

procedure TH1IdleConnectionPool.Put(const AHost: string; const APort: UInt16;
  const AConn: ITcpStream);
var
  LI: Int32;
  LAuthorityIdle: Int32;
  LToClose: array of ITcpStream;
  LCloseCount: Int32;
  LReject: Boolean;
begin
  LCloseCount := 0;
  SetLength(LToClose, 0);
  LReject := False;
  FLock.Acquire;
  try
    { Drop expired peers for this authority so MaxPoolSize counts live idle only. }
    LI := 0;
    while LI < FCount do
    begin
      if (FEntries[LI].Host = AHost) and (FEntries[LI].Port = APort) and
         EntryExpired(LI) then
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
        if (FEntries[LI].Host = AHost) and (FEntries[LI].Port = APort) then
          Inc(LAuthorityIdle);
      if LAuthorityIdle >= FMaxPoolSize then
      begin
        LReject := True;
        Exit;
      end;
    end;
    AConn.SetReadDeadline(TDeadline.Infinite);
    AConn.SetWriteDeadline(TDeadline.Infinite);
    if FCount >= Length(FEntries) then
      SetLength(FEntries, FCount + 4);
    FEntries[FCount].Host := AHost;
    FEntries[FCount].Port := APort;
    FEntries[FCount].Conn := AConn;
    FEntries[FCount].IdleAtMs := GetTickCount64;
    Inc(FCount);
  finally
    FLock.Release;
  end;

  if LReject then
  begin
    if LCloseCount >= Length(LToClose) then
      SetLength(LToClose, LCloseCount + 4);
    LToClose[LCloseCount] := AConn;
    Inc(LCloseCount);
  end;
  for LI := 0 to LCloseCount - 1 do
    if LToClose[LI] <> nil then
    try
      LToClose[LI].Close;
    except
    end;
end;

procedure TH1IdleConnectionPool.Clear;
var
  LI: Int32;
  LToClose: array of ITcpStream;
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
    FCount := 0;
    SetLength(FEntries, 0);
  finally
    FLock.Release;
  end;
  for LI := 0 to LCloseCount - 1 do
    if LToClose[LI] <> nil then
    try
      LToClose[LI].Close;
    except
    end;
end;

end.