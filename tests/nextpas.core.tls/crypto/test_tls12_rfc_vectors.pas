program test_tls12_rfc5246_vectors;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.tls12.handshakecrypto,
  nextpas.core.tls.crypto.tls12prf,
  nextpas.core.tls.crypto.hash;

var
  GPass: Integer = 0;
  GFail: Integer = 0;

procedure Check(ACondition: Boolean; const AMsg: string);
begin
  if ACondition then Inc(GPass)
  else begin Inc(GFail); WriteLn('  FAIL: ', AMsg); end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

procedure TestPRFConsistency;
var
  LSecret, LSeed, LResult1, LResult2: TBytes;
begin
  WriteLn('Test: PRF determinism');
  LSecret := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
  LSeed := HexToBytes('0102030405060708090a0b0c0d0e0f10');

  LResult1 := TLS12PRF_SHA256(LSecret, 'test label', LSeed, 32);
  LResult2 := TLS12PRF_SHA256(LSecret, 'test label', LSeed, 32);
  Check(Length(LResult1) = 32, 'PRF output should be 32 bytes');
  Check(CompareMem(@LResult1[0], @LResult2[0], 32), 'PRF should be deterministic');
end;

procedure TestEMSMasterSecretLength;
var
  LPMS, LHash, LMaster: TBytes;
begin
  WriteLn('Test: EMS master secret is 48 bytes');
  SetLength(LPMS, 32);
  FillChar(LPMS[0], 32, $AB);
  SetLength(LHash, 32);
  FillChar(LHash[0], 32, $CD);

  LMaster := TLS12ComputeMasterSecret_EMS_SHA256(LPMS, LHash);
  Check(Length(LMaster) = 48, 'EMS master secret should be 48 bytes');
end;

procedure TestStandardMasterSecretLength;
var
  LPMS, LCR, LSR, LMaster: TBytes;
begin
  WriteLn('Test: Standard master secret is 48 bytes');
  SetLength(LPMS, 32);
  FillChar(LPMS[0], 32, $11);
  SetLength(LCR, 32);
  FillChar(LCR[0], 32, $22);
  SetLength(LSR, 32);
  FillChar(LSR[0], 32, $33);

  LMaster := TLS12ComputeMasterSecret_SHA256(LPMS, LCR, LSR);
  Check(Length(LMaster) = 48, 'Standard master secret should be 48 bytes');
end;

procedure TestKeyBlockDerivation;
var
  LMaster, LSR, LCR: TBytes;
  LKB: TTLS12KeyBlock;
begin
  WriteLn('Test: Key block derivation produces correct lengths');
  SetLength(LMaster, 48);
  FillChar(LMaster[0], 48, $44);
  SetLength(LSR, 32);
  FillChar(LSR[0], 32, $55);
  SetLength(LCR, 32);
  FillChar(LCR[0], 32, $66);

  LKB := TLS12DeriveKeyBlockFull_SHA256(LMaster, LSR, LCR, 32, 16, 4);
  Check(Length(LKB.ClientWriteMACKey) = 32, 'Client MAC key = 32');
  Check(Length(LKB.ServerWriteMACKey) = 32, 'Server MAC key = 32');
  Check(Length(LKB.ClientWriteKey) = 16, 'Client write key = 16');
  Check(Length(LKB.ServerWriteKey) = 16, 'Server write key = 16');
  Check(Length(LKB.ClientWriteIV) = 4, 'Client IV = 4');
  Check(Length(LKB.ServerWriteIV) = 4, 'Server IV = 4');

  // ChaCha20 key block
  LKB := TLS12DeriveKeyBlockFull_SHA256(LMaster, LSR, LCR, 0, 32, 12);
  Check(Length(LKB.ClientWriteKey) = 32, 'ChaCha20 client key = 32');
  Check(Length(LKB.ClientWriteIV) = 12, 'ChaCha20 client IV = 12');
end;

procedure TestFinishedDiffers;
var
  LMaster, LHash: TBytes;
  LClient, LServer: TBytes;
begin
  WriteLn('Test: Client and server Finished differ');
  SetLength(LMaster, 48);
  FillChar(LMaster[0], 48, $77);
  SetLength(LHash, 32);
  FillChar(LHash[0], 32, $88);

  LClient := TLS12ComputeFinished_SHA256(LMaster, LHash, True);
  LServer := TLS12ComputeFinished_SHA256(LMaster, LHash, False);
  Check(Length(LClient) = 12, 'Client Finished = 12 bytes');
  Check(Length(LServer) = 12, 'Server Finished = 12 bytes');
  Check(not CompareMem(@LClient[0], @LServer[0], 12), 'Client != Server Finished');
end;

begin
  WriteLn('=== TLS 1.2 PRF/KDF Verification Tests ===');
  WriteLn('');

  TestPRFConsistency;
  TestEMSMasterSecretLength;
  TestStandardMasterSecretLength;
  TestKeyBlockDerivation;
  TestFinishedDiffers;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then Halt(1);
end.
