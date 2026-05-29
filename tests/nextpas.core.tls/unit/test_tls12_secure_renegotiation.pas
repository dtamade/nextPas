program test_tls12_secure_renegotiation;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.tls.tls12.clienthello,
  nextpas.core.tls.tls12.parser,
  nextpas.core.tls.tls12.wire;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

procedure AppendByte(var ADest: TBytes; AValue: Byte);
var
  LOldLen: Integer;
begin
  LOldLen := Length(ADest);
  SetLength(ADest, LOldLen + 1);
  ADest[LOldLen] := AValue;
end;

procedure AppendBytes(var ADest: TBytes; const ASrc: TBytes);
var
  LOldLen: Integer;
begin
  if Length(ASrc) = 0 then
    Exit;
  LOldLen := Length(ADest);
  SetLength(ADest, LOldLen + Length(ASrc));
  Move(ASrc[0], ADest[LOldLen], Length(ASrc));
end;

procedure AppendUInt16(var ADest: TBytes; AValue: Word);
begin
  AppendByte(ADest, Byte(AValue shr 8));
  AppendByte(ADest, Byte(AValue));
end;

function ReadUInt16(const AData: TBytes; AOffset: Integer): Word;
begin
  Result := (Word(AData[AOffset]) shl 8) or Word(AData[AOffset + 1]);
end;

function SequenceBytes(ACount: Integer; AStart: Byte): TBytes;
var
  I: Integer;
begin
  SetLength(Result, ACount);
  for I := 0 to High(Result) do
    Result[I] := Byte(AStart + I);
end;

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);
  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);
  Result := True;
end;

function BuildClientHelloWithRenegotiatedConnection(const APreviousVerifyData: TBytes): TBytes;
var
  LOptions: TTLS12ClientHelloOptions;
  LRandom: TBytes;
begin
  FillChar(LOptions, SizeOf(LOptions), 0);
  LOptions.ServerName := 'reneg.test';
  LOptions.SupportEMS := True;
  LOptions.RenegotiatedConnection := Copy(APreviousVerifyData);
  LRandom := SequenceBytes(32, $80);
  Result := BuildTLS12ClientHello(LOptions, LRandom);
end;

function FindClientHelloExtension(const AClientHello: TBytes; AExtType: Word;
  out APayload: TBytes): Boolean;
var
  LPos: Integer;
  LSessionLen: Integer;
  LCipherLen: Integer;
  LCompressionLen: Integer;
  LExtLen: Integer;
  LExtEnd: Integer;
  LType: Word;
  LDataLen: Word;
begin
  Result := False;
  SetLength(APayload, 0);
  if (Length(AClientHello) < 4) or (AClientHello[0] <> TLS12_HANDSHAKE_CLIENT_HELLO) then
    Exit;

  LPos := 4 + 2 + 32;
  if LPos >= Length(AClientHello) then
    Exit;
  LSessionLen := AClientHello[LPos];
  Inc(LPos, 1 + LSessionLen);
  if LPos + 2 > Length(AClientHello) then
    Exit;
  LCipherLen := ReadUInt16(AClientHello, LPos);
  Inc(LPos, 2 + LCipherLen);
  if LPos >= Length(AClientHello) then
    Exit;
  LCompressionLen := AClientHello[LPos];
  Inc(LPos, 1 + LCompressionLen);
  if LPos + 2 > Length(AClientHello) then
    Exit;

  LExtLen := ReadUInt16(AClientHello, LPos);
  Inc(LPos, 2);
  LExtEnd := LPos + LExtLen;
  if LExtEnd > Length(AClientHello) then
    Exit;

  while LPos + 4 <= LExtEnd do
  begin
    LType := ReadUInt16(AClientHello, LPos);
    LDataLen := ReadUInt16(AClientHello, LPos + 2);
    Inc(LPos, 4);
    if LPos + LDataLen > LExtEnd then
      Exit;
    if LType = AExtType then
    begin
      APayload := Copy(AClientHello, LPos, LDataLen);
      Exit(True);
    end;
    Inc(LPos, LDataLen);
  end;
end;

function BuildServerHelloBodyWithRenegotiationInfo(const ARenegotiatedConnection: TBytes): TBytes;
var
  LExtensions: TBytes;
  LRandom: TBytes;
begin
  SetLength(LExtensions, 0);
  AppendUInt16(LExtensions, TLS12_EXT_RENEGOTIATION_INFO);
  AppendUInt16(LExtensions, Word(1 + Length(ARenegotiatedConnection)));
  AppendByte(LExtensions, Byte(Length(ARenegotiatedConnection)));
  AppendBytes(LExtensions, ARenegotiatedConnection);

  SetLength(Result, 0);
  AppendByte(Result, TLS12_VERSION_MAJOR);
  AppendByte(Result, TLS12_VERSION_MINOR);
  LRandom := SequenceBytes(32, $20);
  AppendBytes(Result, LRandom);
  AppendByte(Result, 0);
  AppendUInt16(Result, TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256);
  AppendByte(Result, 0);
  AppendUInt16(Result, Word(Length(LExtensions)));
  AppendBytes(Result, LExtensions);
end;

function BuildMalformedServerHelloBody: TBytes;
var
  LExtensions: TBytes;
  LRandom: TBytes;
begin
  SetLength(LExtensions, 0);
  AppendUInt16(LExtensions, TLS12_EXT_RENEGOTIATION_INFO);
  AppendUInt16(LExtensions, 2);
  AppendByte(LExtensions, 2);
  AppendByte(LExtensions, $AA);

  SetLength(Result, 0);
  AppendByte(Result, TLS12_VERSION_MAJOR);
  AppendByte(Result, TLS12_VERSION_MINOR);
  LRandom := SequenceBytes(32, $40);
  AppendBytes(Result, LRandom);
  AppendByte(Result, 0);
  AppendUInt16(Result, TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256);
  AppendByte(Result, 0);
  AppendUInt16(Result, Word(Length(LExtensions)));
  AppendBytes(Result, LExtensions);
end;

procedure TestInitialClientHelloSendsEmptyRenegotiationInfo;
var
  LClientHello: TBytes;
  LPayload: TBytes;
begin
  WriteLn('TestInitialClientHelloSendsEmptyRenegotiationInfo');
  LClientHello := BuildClientHelloWithRenegotiatedConnection(nil);
  Check(FindClientHelloExtension(LClientHello, TLS12_EXT_RENEGOTIATION_INFO, LPayload),
    'ClientHello contains renegotiation_info');
  Check((Length(LPayload) = 1) and (LPayload[0] = 0),
    'Initial ClientHello sends empty renegotiated_connection');
end;

procedure TestRenegotiationClientHelloSendsPreviousVerifyData;
var
  LClientHello: TBytes;
  LVerifyData: TBytes;
  LPayload: TBytes;
begin
  WriteLn('TestRenegotiationClientHelloSendsPreviousVerifyData');
  LVerifyData := SequenceBytes(12, $01);
  LClientHello := BuildClientHelloWithRenegotiatedConnection(LVerifyData);
  Check(FindClientHelloExtension(LClientHello, TLS12_EXT_RENEGOTIATION_INFO, LPayload),
    'Renegotiation ClientHello contains renegotiation_info');
  Check((Length(LPayload) = 13) and (LPayload[0] = 12),
    'Renegotiation extension vector length is previous client Finished length');
  Check(BytesEqual(Copy(LPayload, 1, 12), LVerifyData),
    'Renegotiation ClientHello carries previous client Finished verify_data');
end;

procedure TestServerHelloParserPreservesRenegotiationInfo;
var
  LBody: TBytes;
  LExpected: TBytes;
  LServerHello: TTLS12ServerHello;
  LError: string;
begin
  WriteLn('TestServerHelloParserPreservesRenegotiationInfo');
  LExpected := SequenceBytes(24, $10);
  LBody := BuildServerHelloBodyWithRenegotiationInfo(LExpected);
  Check(TryParseTLS12ServerHello(LBody, 0, LServerHello, LError),
    'ServerHello with renegotiation_info parses');
  Check(LServerHello.HasRenegotiationInfo,
    'ServerHello records renegotiation_info presence');
  Check(BytesEqual(LServerHello.RenegotiatedConnection, LExpected),
    'ServerHello preserves renegotiated_connection payload');
end;

procedure TestServerHelloParserRejectsMalformedRenegotiationInfo;
var
  LServerHello: TTLS12ServerHello;
  LError: string;
begin
  WriteLn('TestServerHelloParserRejectsMalformedRenegotiationInfo');
  Check(not TryParseTLS12ServerHello(BuildMalformedServerHelloBody, 0, LServerHello, LError),
    'Malformed renegotiation_info vector is rejected');
  Check(Pos('renegotiation_info', LError) > 0,
    'Malformed renegotiation_info reports a focused error');
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestInitialClientHelloSendsEmptyRenegotiationInfo;
  TestRenegotiationClientHelloSendsPreviousVerifyData;
  TestServerHelloParserPreservesRenegotiationInfo;
  TestServerHelloParserRejectsMalformedRenegotiationInfo;

  WriteLn;
  WriteLn('TLS12 secure renegotiation tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
