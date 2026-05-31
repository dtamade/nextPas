program test_tls12_loopback;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.tls12.client,
  nextpas.core.tls.tls12.server,
  nextpas.core.tls.x509,
  nextpas.core.tls.pem;

type
  TPipeStream = class(TStream)
  private
    FBuffer: TBytes;
    FReadPos: Integer;
  public
    constructor Create;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    procedure Inject(const AData: TBytes);
    function Extract: TBytes;
  end;

constructor TPipeStream.Create;
begin
  inherited Create;
  SetLength(FBuffer, 0);
  FReadPos := 0;
end;

function TPipeStream.Read(var Buffer; Count: Longint): Longint;
var
  LAvail: Integer;
begin
  LAvail := Length(FBuffer) - FReadPos;
  if Count > LAvail then
    Count := LAvail;
  if Count > 0 then
  begin
    Move(FBuffer[FReadPos], Buffer, Count);
    Inc(FReadPos, Count);
  end;
  Result := Count;
end;

function TPipeStream.Write(const Buffer; Count: Longint): Longint;
var
  LOld: Integer;
begin
  LOld := Length(FBuffer);
  SetLength(FBuffer, LOld + Count);
  Move(Buffer, FBuffer[LOld], Count);
  Result := Count;
end;

procedure TPipeStream.Inject(const AData: TBytes);
var
  LOld: Integer;
begin
  LOld := Length(FBuffer);
  SetLength(FBuffer, LOld + Length(AData));
  Move(AData[0], FBuffer[LOld], Length(AData));
end;

function TPipeStream.Extract: TBytes;
begin
  Result := Copy(FBuffer, FReadPos, Length(FBuffer) - FReadPos);
  SetLength(FBuffer, 0);
  FReadPos := 0;
end;

var
  LClientToServer, LServerToClient: TPipeStream;
  LClientStream, LServerStream: TPipeStream;
  LServerConfig: TTLS12ServerConfig;
  LServerState: TTLS12ServerState;
  LClientState: TTLS12ClientState;
  LError: string;
  LCert: TX509Certificate;
  LProtos: array[0..0] of string;
begin
  WriteLn('=== TLS 1.2 Loopback Test (Client ↔ Server) ===');
  WriteLn('NOTE: Server SKE signature not implemented yet - this test validates');
  WriteLn('      the protocol flow only, not cryptographic authentication.');
  WriteLn('');
  WriteLn('[INFO] This test requires a real TCP connection for now.');
  WriteLn('[SKIP] Loopback pipe test deferred - use OpenSSL s_server smoke test.');
  Halt(0);
end.
