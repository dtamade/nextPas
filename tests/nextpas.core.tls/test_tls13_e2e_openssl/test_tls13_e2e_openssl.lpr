program test_tls13_e2e_openssl;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.net.tcp,
  nextpas.core.net.intf,
  nextpas.core.io.intf,
  nextpas.core.crypto.x25519,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.keyschedule,
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

const
  SERVER_PORT = 15555;

var
  LStream: ITcpStream;
  LPrivKey, LPubKey: TBytes;
  LClientHello: TBytes;
  LBuf: array[0..16383] of Byte;
  LResponse: TBytes;
  LRead: SizeUInt;
  LHandshake: TBytes;
  LServerHello: TTLS13ServerHelloInfo;
  LShared: TBytes;
  LSecrets: TTLS13HandshakeSecrets;
  LTranscript: TBytes;
  LError: string;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== TLS 1.3 E2E with OpenSSL s_server (framework net) ===');
  WriteLn;

  // Connect using framework's NetTcpConnect
  WriteLn('  Connecting to 127.0.0.1:', SERVER_PORT, '...');
  try
    LStream := NetTcpConnect('127.0.0.1', SERVER_PORT);
    Check('TCP connect ok', LStream <> nil);
  except
    on E: Exception do
    begin
      WriteLn('  FATAL: ', E.Message);
      WriteLn('  (Start server: run_e2e.sh or manually start openssl s_server)');
      Halt(1);
    end;
  end;

  // Build ClientHello
  GenerateX25519KeyPair(LPrivKey, LPubKey);
  LClientHello := BuildTLS13ClientHelloRecord('localhost', 'h2', LPubKey);
  LClientHello[1] := $03; LClientHello[2] := $01;
  Check('ClientHello built', Length(LClientHello) > 100);

  // Send via framework stream
  LStream.Write(LClientHello[0], Length(LClientHello));
  Check('ClientHello sent', True);

  // Wait for response
  Sleep(1500);
  LRead := LStream.Read(LBuf[0], SizeOf(LBuf));
  Check('received response', LRead > 5);

  if LRead > 5 then
  begin
    SetLength(LResponse, LRead);
    Move(LBuf[0], LResponse[0], LRead);

    Check('response is handshake (0x16)', LResponse[0] = $16);
    Check('response version 0x0303', (LResponse[1] = $03) and (LResponse[2] = $03));

    if TryExtractHandshakePayloadFromRecord(LResponse, LHandshake) then
    begin
      Check('extract handshake payload', True);

      if TryParseServerHelloFromHandshake(LHandshake, LServerHello) then
      begin
        Check('parse ServerHello', True);
        Check('TLS 1.3 selected (0x0304)', LServerHello.SelectedVersion = $0304);
        Check('has key share', LServerHello.HasKeyShare);
        Check('key share = X25519', LServerHello.KeyShareGroup = TLS13_GROUP_X25519);
        Check('peer key = 32 bytes', Length(LServerHello.PeerKeyShare) = 32);

        if LServerHello.HasKeyShare and (Length(LServerHello.PeerKeyShare) = 32) then
        begin
          LShared := X25519ComputeSharedSecret(LPrivKey, LServerHello.PeerKeyShare);
          Check('ECDHE shared secret (32 bytes)', Length(LShared) = 32);

          // Derive handshake keys from shared secret
          InitTLS13HandshakeSecrets(LSecrets);
          SetLength(LTranscript, Length(LClientHello) - 5 + Length(LHandshake));
          Move(LClientHello[5], LTranscript[0], Length(LClientHello) - 5);
          Move(LHandshake[0], LTranscript[Length(LClientHello) - 5], Length(LHandshake));

          if TryDeriveTLS13HandshakeSecrets($1301, LShared, LTranscript, LSecrets, LError) then
          begin
            Check('key schedule derived', LSecrets.Valid);
            Check('server key ready', Length(LSecrets.ServerHandshakeKey) > 0);
            WriteLn('  --- Full TLS 1.3 key exchange complete! ---');
          end
          else
            Check('key schedule derived', False);

          ClearTLS13HandshakeSecrets(LSecrets);
        end;
      end
      else
        Check('parse ServerHello', False);
    end
    else
      Check('extract handshake payload', False);
  end;

  LStream.Close;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
