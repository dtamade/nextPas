program test_tls13_e2e_openssl;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  {$IFDEF UNIX}BaseUnix, Unix,{$ENDIF}
  SysUtils, Classes, Sockets,
  nextpas.core.crypto.x25519,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.wire;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPass);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFail);
  end;
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

function ConnectTCP(const AHost: string; APort: Word): LongInt;
var
  LAddr: sockaddr_in;
begin
  Result := fpSocket(AF_INET, SOCK_STREAM, 0);
  if Result < 0 then Exit;

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_port := htons(APort);
  LAddr.sin_addr := StrToNetAddr(AHost);

  if fpConnect(Result, @LAddr, SizeOf(LAddr)) <> 0 then
  begin
    fpClose(Result);
    Result := -1;
  end;
end;

function SendAll(ASock: LongInt; const AData: TBytes): Boolean;
var
  LSent, LTotal: Integer;
begin
  LTotal := 0;
  while LTotal < Length(AData) do
  begin
    LSent := fpSend(ASock, @AData[LTotal], Length(AData) - LTotal, 0);
    if LSent <= 0 then Exit(False);
    Inc(LTotal, LSent);
  end;
  Result := True;
end;

function RecvBytes(ASock: LongInt; AMaxLen: Integer; ATimeoutMs: Integer): TBytes;
var
  LBuf: array[0..16383] of Byte;
  LRead: SizeInt;
begin
  Sleep(ATimeoutMs);
  SetLength(Result, 0);
  LRead := fpRecv(ASock, @LBuf[0], SizeOf(LBuf), MSG_DONTWAIT);
  if LRead > 0 then
  begin
    SetLength(Result, LRead);
    Move(LBuf[0], Result[0], LRead);
  end;
end;

var
  LPort: Word;
  LServerPID: TPid;
  LSock: LongInt;
  LPrivKey, LPubKey: TBytes;
  LClientHello, LResponse: TBytes;
  LHandshake: TBytes;
  LServerHello: TTLS13ServerHelloInfo;
  LShared: TBytes;
  LOk: Boolean;
  LPipeFds: TFilDes;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== TLS 1.3 E2E with OpenSSL s_server ===');
  WriteLn;

  // Server must be pre-started externally (see run_e2e.sh)
  // Default port from environment or 15555
  LPort := 15555;
  WriteLn('  Connecting to openssl s_server on port ', LPort, '...');

  // Connect
  LSock := ConnectTCP('127.0.0.1', LPort);
  Check('TCP connect ok', LSock >= 0);
  if LSock < 0 then
  begin
    WriteLn('    Failed to connect to openssl s_server');
    fpKill(LServerPID, 9);
    fpWaitPid(LServerPID, nil, 0);
    Halt(1);
  end;

  // Generate X25519 key pair and build ClientHello
  GenerateX25519KeyPair(LPrivKey, LPubKey);
  LClientHello := BuildTLS13ClientHelloRecord('localhost', 'h2', LPubKey);
  // Patch record version to 0x0301 (required for initial CH per RFC 8446 §5.1)
  LClientHello[1] := $03;
  LClientHello[2] := $01;
  Check('ClientHello built', Length(LClientHello) > 0);

  // Send ClientHello
  LOk := SendAll(LSock, LClientHello);
  Check('ClientHello sent', LOk);
  WriteLn('  Sent ', Length(LClientHello), ' bytes, waiting 1500ms...');

  // Receive ServerHello
  LResponse := RecvBytes(LSock, 16384, 1500);
  WriteLn('  Received ', Length(LResponse), ' bytes');
  Check('received response', Length(LResponse) > 5);

  if Length(LResponse) > 5 then
  begin
    Check('response is handshake record (0x16)', LResponse[0] = $16);
    Check('response version 0x0303', (LResponse[1] = $03) and (LResponse[2] = $03));

    // Parse ServerHello
    LOk := TryExtractHandshakePayloadFromRecord(LResponse, LHandshake);
    Check('extract handshake payload', LOk);

    if LOk then
    begin
      LOk := TryParseServerHelloFromHandshake(LHandshake, LServerHello);
      Check('parse ServerHello', LOk);

      if LOk then
      begin
        Check('ServerHello valid', LServerHello.Valid);
        Check('selected TLS 1.3 (0x0304)', LServerHello.SelectedVersion = $0304);
        Check('has key share', LServerHello.HasKeyShare);
        Check('key share group = X25519 (0x001D)',
          LServerHello.KeyShareGroup = TLS13_GROUP_X25519);
        Check('peer key share = 32 bytes', Length(LServerHello.PeerKeyShare) = 32);
        Check('cipher suite is AES-128-GCM-SHA256 or AES-256-GCM-SHA384',
          (LServerHello.SelectedCipherSuite = $1301) or
          (LServerHello.SelectedCipherSuite = $1302));

        if LServerHello.HasKeyShare and (Length(LServerHello.PeerKeyShare) = 32) then
        begin
          LShared := X25519ComputeSharedSecret(LPrivKey, LServerHello.PeerKeyShare);
          Check('ECDHE shared secret computed (32 bytes)', Length(LShared) = 32);
        end;
      end;
    end;
  end;

  // Cleanup
  fpClose(LSock);

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
