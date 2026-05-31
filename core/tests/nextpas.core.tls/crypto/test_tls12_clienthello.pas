program test_tls12_clienthello;

{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.core.tls.tls12.wire, nextpas.core.tls.tls12.clienthello;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    Inc(GPassCount)
  else
  begin
    Inc(GFailCount);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

procedure TestClientHelloStructure;
var
  LOptions: TTLS12ClientHelloOptions;
  LRandom: TBytes;
  LHello: TBytes;
  LBodyLen: Integer;
begin
  WriteLn('Test: TLS 1.2 ClientHello structure');
  LOptions.ServerName := 'example.com';
  LOptions.SupportEMS := True;
  SetLength(LOptions.ALPNProtocols, 0);

  SetLength(LRandom, 32);
  FillChar(LRandom[0], 32, $AA);

  LHello := BuildTLS12ClientHello(LOptions, LRandom);

  Check(Length(LHello) > 4, 'ClientHello should have handshake header');
  Check(LHello[0] = TLS12_HANDSHAKE_CLIENT_HELLO, 'First byte should be ClientHello type (1)');

  LBodyLen := (Integer(LHello[1]) shl 16) or (Integer(LHello[2]) shl 8) or Integer(LHello[3]);
  Check(LBodyLen = Length(LHello) - 4, 'Handshake length should match body');

  Check(LHello[4] = TLS12_VERSION_MAJOR, 'Version major should be 3');
  Check(LHello[5] = TLS12_VERSION_MINOR, 'Version minor should be 3');

  Check(LHello[6] = $AA, 'ClientRandom first byte');
  Check(LHello[37] = $AA, 'ClientRandom last byte');

  Check(LHello[38] = 0, 'Session ID length should be 0');
end;

procedure TestClientHelloCipherSuites;
var
  LOptions: TTLS12ClientHelloOptions;
  LRandom: TBytes;
  LHello: TBytes;
  LOffset: Integer;
  LCipherLen: Integer;
  LFirstSuite: Word;
begin
  WriteLn('Test: TLS 1.2 ClientHello cipher suites');
  LOptions.ServerName := '';
  LOptions.SupportEMS := True;
  SetLength(LOptions.ALPNProtocols, 0);

  SetLength(LRandom, 32);
  FillChar(LRandom[0], 32, $BB);

  LHello := BuildTLS12ClientHello(LOptions, LRandom);

  LOffset := 4 + 2 + 32 + 1;
  LCipherLen := (Integer(LHello[LOffset]) shl 8) or Integer(LHello[LOffset + 1]);
  Check(LCipherLen = 16, 'Cipher suite list should be 16 bytes (8 suites)');

  LFirstSuite := (Word(LHello[LOffset + 2]) shl 8) or Word(LHello[LOffset + 3]);
  Check(LFirstSuite = TLS12_CIPHER_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,
    'First cipher suite should be ECDHE_RSA_CHACHA20_POLY1305');
end;

procedure TestClientHelloWithALPN;
var
  LOptions: TTLS12ClientHelloOptions;
  LRandom: TBytes;
  LHello: TBytes;
  I: Integer;
  LFound: Boolean;
begin
  WriteLn('Test: TLS 1.2 ClientHello with ALPN');
  LOptions.ServerName := 'test.com';
  LOptions.SupportEMS := True;
  SetLength(LOptions.ALPNProtocols, 2);
  LOptions.ALPNProtocols[0] := 'h2';
  LOptions.ALPNProtocols[1] := 'http/1.1';

  SetLength(LRandom, 32);
  FillChar(LRandom[0], 32, $CC);

  LHello := BuildTLS12ClientHello(LOptions, LRandom);
  Check(Length(LHello) > 50, 'ClientHello with ALPN should be substantial');

  LFound := False;
  for I := 0 to Length(LHello) - 2 do
    if (LHello[I] = Byte(TLS12_EXT_ALPN shr 8)) and (LHello[I+1] = Byte(TLS12_EXT_ALPN)) then
    begin
      LFound := True;
      Break;
    end;
  Check(LFound, 'ALPN extension should be present');
end;

procedure TestClientHelloEMS;
var
  LOptions: TTLS12ClientHelloOptions;
  LRandom: TBytes;
  LHello: TBytes;
  I: Integer;
  LFound: Boolean;
begin
  WriteLn('Test: TLS 1.2 ClientHello EMS extension');
  LOptions.ServerName := '';
  LOptions.SupportEMS := True;
  SetLength(LOptions.ALPNProtocols, 0);

  SetLength(LRandom, 32);
  FillChar(LRandom[0], 32, $DD);

  LHello := BuildTLS12ClientHello(LOptions, LRandom);

  LFound := False;
  for I := 0 to Length(LHello) - 2 do
    if (LHello[I] = Byte(TLS12_EXT_EXTENDED_MASTER_SECRET shr 8)) and
       (LHello[I+1] = Byte(TLS12_EXT_EXTENDED_MASTER_SECRET)) then
    begin
      LFound := True;
      Break;
    end;
  Check(LFound, 'Extended Master Secret extension should be present');
end;

begin
  WriteLn('=== TLS 1.2 ClientHello Tests ===');
  WriteLn('');

  TestClientHelloStructure;
  TestClientHelloCipherSuites;
  TestClientHelloWithALPN;
  TestClientHelloEMS;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
