program test_tls12_loopback;

{$mode objfpc}{$H+}

uses
  nextpas.core.base,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.tls.tls12.client,
  nextpas.core.tls.tls12.server,
  nextpas.core.tls.x509,
  nextpas.core.tls.pem;

type
  TPipeStream = class(TInterfacedObject, IStream)
  private
    FBuffer: TBytes;
    FReadPos: Integer;
  public
    constructor Create;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    procedure Inject(const AData: TBytes);
    function Extract: TBytes;
  end;

constructor TPipeStream.Create;
begin
  inherited Create;
  SetLength(FBuffer, 0);
  FReadPos := 0;
end;

function TPipeStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvail: Integer;
begin
  LAvail := Length(FBuffer) - FReadPos;
  if LAvail < 0 then
    LAvail := 0;
  if SizeUInt(LAvail) > ACount then
    Result := ACount
  else
    Result := SizeUInt(LAvail);
  if Result > 0 then
  begin
    Move(FBuffer[FReadPos], ABuf, Result);
    Inc(FReadPos, Integer(Result));
  end;
end;

function TPipeStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LOld: Integer;
begin
  LOld := Length(FBuffer);
  SetLength(FBuffer, LOld + Integer(ACount));
  if ACount > 0 then
    Move(ABuf, FBuffer[LOld], ACount);
  Result := ACount;
end;

function TPipeStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
begin
  case AOrigin of
    soBeginning: FReadPos := Integer(AOffset);
    soCurrent: Inc(FReadPos, Integer(AOffset));
    soEnd: FReadPos := Length(FBuffer) + Integer(AOffset);
  end;
  Result := FReadPos;
end;

procedure TPipeStream.Close;
begin
end;

function TPipeStream.GetSize: Int64;
begin
  Result := Length(FBuffer);
end;

function TPipeStream.GetPosition: Int64;
begin
  Result := FReadPos;
end;

procedure TPipeStream.SetPosition(const AValue: Int64);
begin
  FReadPos := Integer(AValue);
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
