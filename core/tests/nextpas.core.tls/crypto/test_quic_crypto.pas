program test_quic_crypto;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.quic.crypto;

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

function HexNibble(AChar: Char): Byte;
begin
  case AChar of
    '0'..'9': Result := Byte(Ord(AChar) - Ord('0'));
    'a'..'f': Result := Byte(Ord(AChar) - Ord('a') + 10);
    'A'..'F': Result := Byte(Ord(AChar) - Ord('A') + 10);
  else
    raise Exception.Create('Invalid hex digit: ' + AChar);
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  if (Length(AHex) and 1) <> 0 then
    raise Exception.Create('Hex string length must be even');

  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := Byte((HexNibble(AHex[I * 2 + 1]) shl 4) or HexNibble(AHex[I * 2 + 2]));
end;

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);
  if Length(ALeft) = 0 then
    Exit(True);
  Result := CompareMem(@ALeft[0], @ARight[0], Length(ALeft));
end;

procedure TestInitialSecretDeterminism;
var
  LConnID: TBytes;
  LSecretA: TBytes;
  LSecretB: TBytes;
begin
  WriteLn('Test: QUIC initial secret determinism');
  SetLength(LConnID, 8);
  FillChar(LConnID[0], Length(LConnID), $AB);

  LSecretA := QUICDeriveInitialSecret(LConnID);
  LSecretB := QUICDeriveInitialSecret(LConnID);

  Check(Length(LSecretA) = 32, 'Initial secret should be 32 bytes');
  Check(BytesEqual(LSecretA, LSecretB), 'Same connection ID should derive same secret');
end;

procedure TestClientAndServerLabelsProduceDistinctKeys;
var
  LConnID: TBytes;
  LSecret: TBytes;
  LClientKeys: TQUICKeys;
  LServerKeys: TQUICKeys;
begin
  WriteLn('Test: QUIC client/server labels produce distinct keys');
  SetLength(LConnID, 4);
  FillChar(LConnID[0], Length(LConnID), $CD);

  LSecret := QUICDeriveInitialSecret(LConnID);
  LClientKeys := QUICDeriveClientInitialKeys(LSecret);
  LServerKeys := QUICDeriveServerInitialKeys(LSecret);

  Check(Length(LClientKeys.Key) = 16, 'Client key should be 16 bytes');
  Check(Length(LClientKeys.IV) = 12, 'Client IV should be 12 bytes');
  Check(Length(LClientKeys.HP) = 16, 'Client HP should be 16 bytes');
  Check(Length(LServerKeys.Key) = 16, 'Server key should be 16 bytes');
  Check(Length(LServerKeys.IV) = 12, 'Server IV should be 12 bytes');
  Check(Length(LServerKeys.HP) = 16, 'Server HP should be 16 bytes');

  Check(not BytesEqual(LClientKeys.Key, LServerKeys.Key),
    'Client and server label bytes should derive different keys');
  Check(not BytesEqual(LClientKeys.IV, LServerKeys.IV),
    'Client and server label bytes should derive different IVs');
  Check(not BytesEqual(LClientKeys.HP, LServerKeys.HP),
    'Client and server label bytes should derive different HP keys');
end;

procedure TestRFC9001KnownVector;
var
  LConnID: TBytes;
  LInitialSecret: TBytes;
  LClientKeys: TQUICKeys;
  LServerKeys: TQUICKeys;
begin
  WriteLn('Test: QUIC RFC 9001 initial secret and key vector');
  LConnID := HexToBytes('8394c8f03e515708');

  LInitialSecret := QUICDeriveInitialSecret(LConnID);
  Check(BytesEqual(LInitialSecret,
    HexToBytes('7db5df06e7a69e432496adedb00851923595221596ae2ae9fb8115c1e9ed0a44')),
    'Initial secret should match RFC 9001 Appendix A.1');

  LClientKeys := QUICDeriveClientInitialKeys(LInitialSecret);
  Check(BytesEqual(LClientKeys.Key,
    HexToBytes('1f369613dd76d5467730efcbe3b1a22d')),
    'Client key should match RFC 9001 Appendix A.1');
  Check(BytesEqual(LClientKeys.IV,
    HexToBytes('fa044b2f42a3fd3b46fb255c')),
    'Client IV should match RFC 9001 Appendix A.1');
  Check(BytesEqual(LClientKeys.HP,
    HexToBytes('9f50449e04a0e810283a1e9933adedd2')),
    'Client HP key should match RFC 9001 Appendix A.1');

  LServerKeys := QUICDeriveServerInitialKeys(LInitialSecret);
  Check(BytesEqual(LServerKeys.Key,
    HexToBytes('cf3a5331653c364c88f0f379b6067e37')),
    'Server key should match RFC 9001 Appendix A.1');
  Check(BytesEqual(LServerKeys.IV,
    HexToBytes('0ac1493ca1905853b0bba03e')),
    'Server IV should match RFC 9001 Appendix A.1');
  Check(BytesEqual(LServerKeys.HP,
    HexToBytes('c206b8d9b9f0f37644430b490eeaa314')),
    'Server HP key should match RFC 9001 Appendix A.1');
end;

begin
  WriteLn('=== QUIC Crypto Tests ===');
  WriteLn('');

  TestInitialSecretDeterminism;
  TestClientAndServerLabelsProduceDistinctKeys;
  TestRFC9001KnownVector;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
