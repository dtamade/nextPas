unit nextpas.core.tls.http2.alpn;

{$mode objfpc}{$H+}{$J-}

interface

uses nextpas.core.base, nextpas.core.time, nextpas.core.tls.base;

const
  HTTP2_ALPN_PROTOCOL = 'h2';
  HTTP11_ALPN_PROTOCOL = 'http/1.1';

type
  TSSLConnectionPool = class
  private
    FConnections: array of record
      Host: string;
      Port: Word;
      Connection: ISSLConnection;
      LastUsed: TDateTime;
      InUse: Boolean;
    end;
    FMaxConnections: Integer;
    FIdleTimeout: Integer;
  public
    constructor Create(AMaxConnections: Integer = 8; AIdleTimeoutSec: Integer = 60);
    destructor Destroy; override;
    function Acquire(const AHost: string; APort: Word): ISSLConnection;
    procedure Release(AConnection: ISSLConnection);
    procedure CleanupIdle;
    function ActiveCount: Integer;
    function IdleCount: Integer;
  end;

function GetHTTP2ALPNProtocols: TStringArray;

implementation

uses nextpas.core.time;

function SecondsBetween(const ANewer, AOlder: TDateTime): Int64;
begin
  Result := Trunc((ANewer - AOlder) * 86400.0);
end;

function GetHTTP2ALPNProtocols: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := HTTP2_ALPN_PROTOCOL;
  Result[1] := HTTP11_ALPN_PROTOCOL;
end;

constructor TSSLConnectionPool.Create(AMaxConnections: Integer; AIdleTimeoutSec: Integer);
begin
  inherited Create;
  FMaxConnections := AMaxConnections;
  FIdleTimeout := AIdleTimeoutSec;
  SetLength(FConnections, 0);
end;

destructor TSSLConnectionPool.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FConnections) do
    FConnections[I].Connection := nil;
  SetLength(FConnections, 0);
  inherited;
end;

function TSSLConnectionPool.Acquire(const AHost: string; APort: Word): ISSLConnection;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to High(FConnections) do
  begin
    if (not FConnections[I].InUse) and
       (FConnections[I].Host = AHost) and
       (FConnections[I].Port = APort) and
       (FConnections[I].Connection <> nil) then
    begin
      FConnections[I].InUse := True;
      FConnections[I].LastUsed := nextpas.core.time.DateTimeNow;
      Result := FConnections[I].Connection;
      Exit;
    end;
  end;
end;

procedure TSSLConnectionPool.Release(AConnection: ISSLConnection);
var
  I, LSlot: Integer;
begin
  for I := 0 to High(FConnections) do
  begin
    if FConnections[I].Connection = AConnection then
    begin
      FConnections[I].InUse := False;
      FConnections[I].LastUsed := nextpas.core.time.DateTimeNow;
      Exit;
    end;
  end;

  // New connection — add to pool if space available
  if Length(FConnections) < FMaxConnections then
  begin
    LSlot := Length(FConnections);
    SetLength(FConnections, LSlot + 1);
    FConnections[LSlot].Connection := AConnection;
    FConnections[LSlot].InUse := False;
    FConnections[LSlot].LastUsed := nextpas.core.time.DateTimeNow;
    FConnections[LSlot].Host := '';
    FConnections[LSlot].Port := 0;
  end;
end;

procedure TSSLConnectionPool.CleanupIdle;
var
  I: Integer;
  LNow: TDateTime;
begin
  LNow := nextpas.core.time.DateTimeNow;
  for I := High(FConnections) downto 0 do
  begin
    if (not FConnections[I].InUse) and
       (SecondsBetween(LNow, FConnections[I].LastUsed) > FIdleTimeout) then
    begin
      FConnections[I].Connection := nil;
      FConnections[I] := FConnections[High(FConnections)];
      SetLength(FConnections, Length(FConnections) - 1);
    end;
  end;
end;

function TSSLConnectionPool.ActiveCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FConnections) do
    if FConnections[I].InUse then Inc(Result);
end;

function TSSLConnectionPool.IdleCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FConnections) do
    if (not FConnections[I].InUse) and (FConnections[I].Connection <> nil) then
      Inc(Result);
end;

end.
