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

begin
  WriteLn('=== QUIC Crypto Tests ===');
  WriteLn('');

  TestInitialSecretDeterminism;
  TestClientAndServerLabelsProduceDistinctKeys;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
