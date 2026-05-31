unit nextpas.core.tls.pool;

{$mode ObjFPC}{$H+}{$J-}

interface

uses
  SysUtils, Classes, SyncObjs,
  nextpas.core.tls.base,
  nextpas.core.tls.tls,
  nextpas.core.tls.dialer;

type
  TSSLPoolEntry = record
    Host: string;
    Port: Word;
    Stream: TSSLStream;
    IdleSince: TDateTime;
  end;

  TSSLConnectionPool = class
  private
    FEntries: array of TSSLPoolEntry;
    FLock: TCriticalSection;
    FDialer: TSSLDialer;
    FMaxIdle: Integer;
    FIdleTimeoutMs: Integer;
  public
    constructor Create(ADialer: TSSLDialer; AMaxIdle: Integer = 10;
      AIdleTimeoutMs: Integer = 60000);
    destructor Destroy; override;

    function Acquire(const AHost: string; APort: Word;
      out AStream: TSSLStream; out AError: string): Boolean;
    procedure Release(const AHost: string; APort: Word; AStream: TSSLStream);
    procedure CloseIdle;
    procedure CloseAll;

    property MaxIdle: Integer read FMaxIdle write FMaxIdle;
    property IdleTimeoutMs: Integer read FIdleTimeoutMs write FIdleTimeoutMs;
  end;

implementation

uses
  DateUtils;

constructor TSSLConnectionPool.Create(ADialer: TSSLDialer; AMaxIdle: Integer;
  AIdleTimeoutMs: Integer);
begin
  inherited Create;
  FDialer := ADialer;
  FMaxIdle := AMaxIdle;
  FIdleTimeoutMs := AIdleTimeoutMs;
  FLock := TCriticalSection.Create;
  SetLength(FEntries, 0);
end;

destructor TSSLConnectionPool.Destroy;
begin
  CloseAll;
  FLock.Free;
  inherited Destroy;
end;

function TSSLConnectionPool.Acquire(const AHost: string; APort: Word;
  out AStream: TSSLStream; out AError: string): Boolean;
var
  I: Integer;
  LNow: TDateTime;
  LExpired: TSSLStream;
begin
  AStream := nil;
  AError := '';
  Result := False;
  LNow := Now;
  LExpired := nil;

  FLock.Enter;
  try
    // Find matching idle connection
    for I := High(FEntries) downto 0 do
    begin
      if (FEntries[I].Host = AHost) and (FEntries[I].Port = APort) then
      begin
        // Check if not expired
        if MilliSecondsBetween(LNow, FEntries[I].IdleSince) < FIdleTimeoutMs then
        begin
          AStream := FEntries[I].Stream;
          // Remove from pool
          FEntries[I] := FEntries[High(FEntries)];
          SetLength(FEntries, Length(FEntries) - 1);
          Result := True;
          Exit;
        end
        else
        begin
          // Expired — remove from pool, free after unlock
          LExpired := FEntries[I].Stream;
          FEntries[I] := FEntries[High(FEntries)];
          SetLength(FEntries, Length(FEntries) - 1);
        end;
      end;
    end;
  finally
    FLock.Leave;
  end;

  // Free expired stream outside lock (may block on shutdown)
  if LExpired <> nil then
    LExpired.Free;

  // No idle connection found — create new
  Result := FDialer.TryDial(AHost, APort, AStream, AError);
end;

procedure TSSLConnectionPool.Release(const AHost: string; APort: Word;
  AStream: TSSLStream);
var
  LIdx: Integer;
begin
  if AStream = nil then Exit;

  // MaxIdle=0 means don't pool — close immediately
  if FMaxIdle <= 0 then
  begin
    AStream.Free;
    Exit;
  end;

  FLock.Enter;
  try
    // Check pool capacity
    if Length(FEntries) >= FMaxIdle then
    begin
      // Pool full — close oldest
      if Length(FEntries) > 0 then
      begin
        FEntries[0].Stream.Free;
        FEntries[0] := FEntries[High(FEntries)];
        SetLength(FEntries, Length(FEntries) - 1);
      end;
    end;

    LIdx := Length(FEntries);
    SetLength(FEntries, LIdx + 1);
    FEntries[LIdx].Host := AHost;
    FEntries[LIdx].Port := APort;
    FEntries[LIdx].Stream := AStream;
    FEntries[LIdx].IdleSince := Now;
  finally
    FLock.Leave;
  end;
end;

procedure TSSLConnectionPool.CloseIdle;
var
  I: Integer;
  LNow: TDateTime;
begin
  LNow := Now;
  FLock.Enter;
  try
    I := 0;
    while I <= High(FEntries) do
    begin
      if MilliSecondsBetween(LNow, FEntries[I].IdleSince) >= FIdleTimeoutMs then
      begin
        FEntries[I].Stream.Free;
        FEntries[I] := FEntries[High(FEntries)];
        SetLength(FEntries, Length(FEntries) - 1);
      end
      else
        Inc(I);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSSLConnectionPool.CloseAll;
var
  I: Integer;
begin
  FLock.Enter;
  try
    for I := 0 to High(FEntries) do
      FEntries[I].Stream.Free;
    SetLength(FEntries, 0);
  finally
    FLock.Leave;
  end;
end;

end.
