program test_tls12_handshake;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.tls12.wire,
  nextpas.core.tls.tls12.parser,
  nextpas.core.tls.tls12.recordcrypto,
  nextpas.core.tls.tls12.handshakecrypto;

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

procedure TestServerHelloParse;
var
  LData: TBytes;
  LSH: TTLS12ServerHello;
  LError: string;
  LOk: Boolean;
begin
  WriteLn('Test: Parse TLS 1.2 ServerHello');
  SetLength(LData, 0);
  SetLength(LData, 44);
  LData[0] := 3; LData[1] := 3;
  FillChar(LData[2], 32, $BB);
  LData[34] := 0;
  LData[35] := $C0; LData[36] := $2F;
  LData[37] := 0;
  LData[38] := 0; LData[39] := 4;
  LData[40] := 0; LData[41] := 23;
  LData[42] := 0; LData[43] := 0;

  LOk := TryParseTLS12ServerHello(LData, 0, LSH, LError);
  Check(LOk, 'ServerHello parse should succeed: ' + LError);
  Check(LSH.Version = $0303, 'Version should be TLS 1.2');
  Check(LSH.CipherSuite = $C02F, 'Cipher suite should be ECDHE_RSA_AES_128_GCM_SHA256');
  Check(LSH.HasEMS, 'EMS extension should be present');
  Check(Length(LSH.ServerRandom) = 32, 'ServerRandom should be 32 bytes');
end;

procedure TestGCMRecordRoundtrip;
var
  LKey, LIV, LPlaintext, LEncrypted, LDecrypted: TBytes;
  LOk: Boolean;
  LError: string;
begin
  WriteLn('Test: TLS 1.2 GCM record encrypt/decrypt roundtrip');
  SetLength(LKey, 16);
  FillChar(LKey[0], 16, $11);
  SetLength(LIV, 4);
  FillChar(LIV[0], 4, $22);
  LPlaintext := TEncoding.ASCII.GetBytes('Hello TLS 1.2 GCM!');

  LOk := TLS12GCMEncryptRecord(LKey, LIV, 0, 23, LPlaintext, LEncrypted, LError);
  Check(LOk, 'GCM encrypt should succeed: ' + LError);
  Check(Length(LEncrypted) = 8 + Length(LPlaintext) + 16, 'Encrypted = explicit_nonce + ciphertext + tag');

  LOk := TLS12GCMDecryptRecord(LKey, LIV, 0, 23, LEncrypted, LDecrypted, LError);
  Check(LOk, 'GCM decrypt should succeed: ' + LError);
  Check(TEncoding.ASCII.GetString(LDecrypted) = 'Hello TLS 1.2 GCM!', 'Decrypted should match');
end;

procedure TestGCMRecordBadTag;
var
  LKey, LIV, LPlaintext, LEncrypted, LDecrypted: TBytes;
  LOk: Boolean;
  LError: string;
begin
  WriteLn('Test: TLS 1.2 GCM record bad tag detection');
  SetLength(LKey, 16);
  FillChar(LKey[0], 16, $33);
  SetLength(LIV, 4);
  FillChar(LIV[0], 4, $44);
  LPlaintext := TEncoding.ASCII.GetBytes('test');

  TLS12GCMEncryptRecord(LKey, LIV, 5, 23, LPlaintext, LEncrypted, LError);
  LEncrypted[Length(LEncrypted) - 1] := LEncrypted[Length(LEncrypted) - 1] xor $FF;

  LOk := TLS12GCMDecryptRecord(LKey, LIV, 5, 23, LEncrypted, LDecrypted, LError);
  Check(not LOk, 'Bad tag should fail');
  Check(LError = 'bad_record_mac', 'Error should be bad_record_mac');
end;

procedure TestEMSMasterSecret;
var
  LPMS, LHash, LMaster: TBytes;
begin
  WriteLn('Test: TLS 1.2 EMS master secret derivation');
  SetLength(LPMS, 48);
  FillChar(LPMS[0], 48, $55);
  SetLength(LHash, 32);
  FillChar(LHash[0], 32, $66);

  LMaster := TLS12ComputeMasterSecret_EMS_SHA256(LPMS, LHash);
  Check(Length(LMaster) = 48, 'Master secret should be 48 bytes');
end;

procedure TestKeyBlockDerivation;
var
  LMaster, LServerRandom, LClientRandom: TBytes;
  LKeyBlock: TTLS12KeyBlock;
begin
  WriteLn('Test: TLS 1.2 key block derivation');
  SetLength(LMaster, 48);
  FillChar(LMaster[0], 48, $77);
  SetLength(LServerRandom, 32);
  FillChar(LServerRandom[0], 32, $88);
  SetLength(LClientRandom, 32);
  FillChar(LClientRandom[0], 32, $99);

  LKeyBlock := TLS12DeriveKeyBlock_SHA256(LMaster, LServerRandom, LClientRandom, 16, 4);
  Check(Length(LKeyBlock.ClientWriteKey) = 16, 'Client write key should be 16 bytes');
  Check(Length(LKeyBlock.ServerWriteKey) = 16, 'Server write key should be 16 bytes');
  Check(Length(LKeyBlock.ClientWriteIV) = 4, 'Client write IV should be 4 bytes');
  Check(Length(LKeyBlock.ServerWriteIV) = 4, 'Server write IV should be 4 bytes');
end;

procedure TestFinishedComputation;
var
  LMaster, LHash: TBytes;
  LClientFinished, LServerFinished: TBytes;
begin
  WriteLn('Test: TLS 1.2 Finished verify_data');
  SetLength(LMaster, 48);
  FillChar(LMaster[0], 48, $AA);
  SetLength(LHash, 32);
  FillChar(LHash[0], 32, $BB);

  LClientFinished := TLS12ComputeFinished_SHA256(LMaster, LHash, True);
  LServerFinished := TLS12ComputeFinished_SHA256(LMaster, LHash, False);

  Check(Length(LClientFinished) = 12, 'Client Finished should be 12 bytes');
  Check(Length(LServerFinished) = 12, 'Server Finished should be 12 bytes');
  Check(not CompareMem(@LClientFinished[0], @LServerFinished[0], 12),
    'Client and server Finished must differ');
end;

begin
  WriteLn('=== TLS 1.2 Handshake & Record Tests ===');
  WriteLn('');

  TestServerHelloParse;
  TestGCMRecordRoundtrip;
  TestGCMRecordBadTag;
  TestEMSMasterSecret;
  TestKeyBlockDerivation;
  TestFinishedComputation;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
