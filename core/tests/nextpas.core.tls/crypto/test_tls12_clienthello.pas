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

function ReadUInt16(const AData: TBytes; AOffset: Integer): Word;
begin
  Result := (Word(AData[AOffset]) shl 8) or Word(AData[AOffset + 1]);
end;

function TryFindClientHelloExtension(const AHello: TBytes; AExtensionType: Word;
  out ADataOffset: Integer; out ADataLength: Integer): Boolean;
var
  LOffset: Integer;
  LSessionLen: Integer;
  LCipherLen: Integer;
  LCompressionLen: Integer;
  LExtensionsEnd: Integer;
  LExtensionType: Word;
  LExtensionLen: Integer;
begin
  Result := False;
  ADataOffset := 0;
  ADataLength := 0;

  if (Length(AHello) < 4 + 2 + 32 + 1) or (AHello[0] <> TLS12_HANDSHAKE_CLIENT_HELLO) then
    Exit;

  LOffset := 4 + 2 + 32;
  LSessionLen := AHello[LOffset];
  Inc(LOffset);
  if LOffset + LSessionLen + 2 > Length(AHello) then
    Exit;
  Inc(LOffset, LSessionLen);

  LCipherLen := ReadUInt16(AHello, LOffset);
  Inc(LOffset, 2);
  if LOffset + LCipherLen + 1 > Length(AHello) then
    Exit;
  Inc(LOffset, LCipherLen);

  LCompressionLen := AHello[LOffset];
  Inc(LOffset);
  if LOffset + LCompressionLen + 2 > Length(AHello) then
    Exit;
  Inc(LOffset, LCompressionLen);

  LExtensionsEnd := LOffset + 2 + ReadUInt16(AHello, LOffset);
  Inc(LOffset, 2);
  if LExtensionsEnd > Length(AHello) then
    Exit;

  while LOffset + 4 <= LExtensionsEnd do
  begin
    LExtensionType := ReadUInt16(AHello, LOffset);
    LExtensionLen := ReadUInt16(AHello, LOffset + 2);
    Inc(LOffset, 4);
    if LOffset + LExtensionLen > LExtensionsEnd then
      Exit;

    if LExtensionType = AExtensionType then
    begin
      ADataOffset := LOffset;
      ADataLength := LExtensionLen;
      Exit(True);
    end;

    Inc(LOffset, LExtensionLen);
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
  LOffset: Integer;
  LLength: Integer;
  LExtLen: Integer;
  LProtoListLen: Integer;
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

  Check(TryFindClientHelloExtension(LHello, TLS12_EXT_ALPN, LOffset, LLength),
    'ALPN extension should be present');
  LExtLen := LLength;
  LProtoListLen := ReadUInt16(LHello, LOffset);
  Check(LExtLen = 14, 'ALPN extension length should match protocol list');
  Check(LProtoListLen = 12, 'ALPN protocol list length should match h2/http1.1');
  Check(LHello[LOffset + 2] = 2, 'First ALPN protocol length should be 2');
  Check((LHello[LOffset + 3] = Ord('h')) and (LHello[LOffset + 4] = Ord('2')),
    'First ALPN protocol should be h2 bytes');
  Check(LHello[LOffset + 5] = 8, 'Second ALPN protocol length should be 8');
  Check((LHello[LOffset + 6] = Ord('h')) and (LHello[LOffset + 13] = Ord('1')),
    'Second ALPN protocol should be http/1.1 bytes');
end;

procedure TestClientHelloSNIUsesHostBytes;
var
  LOptions: TTLS12ClientHelloOptions;
  LRandom: TBytes;
  LHello: TBytes;
  LOffset: Integer;
  LLength: Integer;
begin
  WriteLn('Test: TLS 1.2 ClientHello SNI host bytes');
  LOptions.ServerName := 'api.example';
  LOptions.SupportEMS := False;
  SetLength(LOptions.ALPNProtocols, 0);

  SetLength(LRandom, 32);
  FillChar(LRandom[0], 32, $CE);

  LHello := BuildTLS12ClientHello(LOptions, LRandom);

  Check(TryFindClientHelloExtension(LHello, TLS12_EXT_SERVER_NAME, LOffset, LLength),
    'SNI extension should be present');
  Check(LLength = 16, 'SNI extension length should match hostname');
  Check(ReadUInt16(LHello, LOffset) = 14, 'SNI list length should match hostname');
  Check(LHello[LOffset + 2] = 0, 'SNI name type should be host_name');
  Check(ReadUInt16(LHello, LOffset + 3) = 11, 'SNI host length should be 11');
  Check((LHello[LOffset + 5] = Ord('a')) and (LHello[LOffset + 15] = Ord('e')),
    'SNI host bytes should be copied verbatim');
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
  TestClientHelloSNIUsesHostBytes;
  TestClientHelloEMS;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
