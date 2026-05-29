program test_ct_pure;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.tls.base64,
  nextpas.core.tls.ct.logs,
  nextpas.core.tls.ct.pure,
  nextpas.core.tls.crypto.ed25519,
  nextpas.core.tls.crypto.hash;

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

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function SameBytes(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  Result := Length(ALeft) = Length(ARight);
  if not Result then
    Exit;

  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);
end;

procedure AppendByte(var AData: TBytes; AValue: Byte);
var
  LLen: Integer;
begin
  LLen := Length(AData);
  SetLength(AData, LLen + 1);
  AData[LLen] := AValue;
end;

procedure AppendBytes(var AData: TBytes; const AValue: TBytes);
var
  LLen: Integer;
begin
  if Length(AValue) = 0 then
    Exit;

  LLen := Length(AData);
  SetLength(AData, LLen + Length(AValue));
  Move(AValue[0], AData[LLen], Length(AValue));
end;

procedure AppendUInt16(var AData: TBytes; AValue: Word);
begin
  AppendByte(AData, Byte(AValue shr 8));
  AppendByte(AData, Byte(AValue));
end;

procedure AppendUInt64(var AData: TBytes; AValue: UInt64);
begin
  AppendByte(AData, Byte(AValue shr 56));
  AppendByte(AData, Byte(AValue shr 48));
  AppendByte(AData, Byte(AValue shr 40));
  AppendByte(AData, Byte(AValue shr 32));
  AppendByte(AData, Byte(AValue shr 24));
  AppendByte(AData, Byte(AValue shr 16));
  AppendByte(AData, Byte(AValue shr 8));
  AppendByte(AData, Byte(AValue));
end;

function BuildSCTSignedDataForTest(const ASCT: TSignedCertificateTimestamp;
  const ALeafCertDER: TBytes): TBytes;
var
  LCertLen: Integer;
begin
  SetLength(Result, 0);
  LCertLen := Length(ALeafCertDER);

  AppendByte(Result, ASCT.Version);
  AppendByte(Result, 0);
  AppendUInt64(Result, ASCT.Timestamp);
  AppendUInt16(Result, 0);
  AppendByte(Result, Byte(LCertLen shr 16));
  AppendByte(Result, Byte(LCertLen shr 8));
  AppendByte(Result, Byte(LCertLen));
  AppendBytes(Result, ALeafCertDER);
  AppendUInt16(Result, Length(ASCT.Extensions));
  AppendBytes(Result, ASCT.Extensions);
end;

function SerializeSingleSCT(const ASCT: TSignedCertificateTimestamp): TBytes;
begin
  SetLength(Result, 0);
  AppendByte(Result, ASCT.Version);
  AppendBytes(Result, ASCT.LogID);
  AppendUInt64(Result, ASCT.Timestamp);
  AppendUInt16(Result, Length(ASCT.Extensions));
  AppendBytes(Result, ASCT.Extensions);
  AppendByte(Result, ASCT.HashAlgorithm);
  AppendByte(Result, ASCT.SignatureAlgorithm);
  AppendUInt16(Result, Length(ASCT.Signature));
  AppendBytes(Result, ASCT.Signature);
end;

function BuildSCTList(const ASCT: TSignedCertificateTimestamp): TBytes;
var
  LSerialized: TBytes;
begin
  LSerialized := SerializeSingleSCT(ASCT);
  SetLength(Result, 0);
  AppendUInt16(Result, Length(LSerialized) + 2);
  AppendUInt16(Result, Length(LSerialized));
  AppendBytes(Result, LSerialized);
end;

procedure TestParseSingleSCT;
var
  LData: TBytes;
  LSCT: TSignedCertificateTimestamp;
  LConsumed: Integer;
begin
  WriteLn('TestParseSingleSCT');
  // Build a minimal valid SCT v1
  SetLength(LData, 1 + 32 + 8 + 2 + 2 + 2 + 4);
  LData[0] := 0; // version 1
  FillChar(LData[1], 32, $AB); // log_id
  FillChar(LData[33], 8, 0); LData[40] := 1; // timestamp = 1
  LData[41] := 0; LData[42] := 0; // extensions length = 0
  LData[43] := 4; // hash = SHA-256
  LData[44] := 3; // sig = ECDSA
  LData[45] := 0; LData[46] := 4; // sig length = 4
  LData[47] := $DE; LData[48] := $AD; LData[49] := $BE; LData[50] := $EF;

  Check(TryParseSingleSCT(LData, 0, LSCT, LConsumed), 'Parse succeeds');
  Check(LSCT.Version = 0, 'Version = 0');
  Check(Length(LSCT.LogID) = 32, 'LogID = 32 bytes');
  Check(LSCT.LogID[0] = $AB, 'LogID content');
  Check(LSCT.HashAlgorithm = 4, 'Hash = SHA-256');
  Check(LSCT.SignatureAlgorithm = 3, 'Sig = ECDSA');
  Check(Length(LSCT.Signature) = 4, 'Signature length');
  Check(LSCT.Signature[0] = $DE, 'Signature content');
  Check(LConsumed = 51, 'Consumed bytes');
end;

procedure TestParseSCTTooShort;
var
  LData: TBytes;
  LSCT: TSignedCertificateTimestamp;
  LConsumed: Integer;
begin
  WriteLn('TestParseSCTTooShort');
  SetLength(LData, 5);
  Check(not TryParseSingleSCT(LData, 0, LSCT, LConsumed), 'Too short rejected');
end;

procedure TestParseSCTWrongVersion;
var
  LData: TBytes;
  LSCT: TSignedCertificateTimestamp;
  LConsumed: Integer;
begin
  WriteLn('TestParseSCTWrongVersion');
  SetLength(LData, 50);
  LData[0] := 1; // version 2 (unsupported)
  Check(not TryParseSingleSCT(LData, 0, LSCT, LConsumed), 'Version 2 rejected');
end;

procedure TestVerifySCTCount;
begin
  WriteLn('TestVerifySCTCount');
  Check(VerifySCTCount(1, 'DV'), '1 SCT enough for DV');
  Check(VerifySCTCount(2, 'EV'), '2 SCTs enough for EV');
  Check(not VerifySCTCount(1, 'EV'), '1 SCT not enough for EV');
  Check(not VerifySCTCount(0, 'DV'), '0 SCTs not enough');
end;

procedure TestVerifySCTSignatureInvalid;
var
  LSCT: TSignedCertificateTimestamp;
  LCert, LPubKey: TBytes;
  LResult: TSCTVerifyResult;
begin
  WriteLn('TestVerifySCTSignatureInvalid');
  FillChar(LSCT, SizeOf(LSCT), 0);
  LSCT.Version := 0;
  SetLength(LSCT.LogID, 32);
  LSCT.Timestamp := 1000;
  SetLength(LSCT.Extensions, 0);
  SetLength(LSCT.Signature, 64);
  FillChar(LSCT.Signature[0], 64, $FF);

  SetLength(LCert, 10);
  SetLength(LPubKey, 32);
  FillChar(LPubKey[0], 32, $42);

  LResult := VerifySCTSignature(LSCT, LCert, LPubKey, 'Ed25519');
  Check(LResult = sctInvalidSignature, 'Invalid Ed25519 SCT signature rejected');
end;

procedure TestVerifySCTSignatureECDSAInvalid;
var
  LSCT: TSignedCertificateTimestamp;
  LCert, LPubKey: TBytes;
  LResult: TSCTVerifyResult;
begin
  WriteLn('TestVerifySCTSignatureECDSAInvalid');
  FillChar(LSCT, SizeOf(LSCT), 0);
  LSCT.Version := 0;
  SetLength(LSCT.LogID, 32);
  LSCT.Timestamp := 2000;
  SetLength(LSCT.Extensions, 0);
  SetLength(LSCT.Signature, 70);
  FillChar(LSCT.Signature[0], 70, $AA);

  SetLength(LCert, 20);
  SetLength(LPubKey, 65);
  LPubKey[0] := $04;
  FillChar(LPubKey[1], 64, $33);

  LResult := VerifySCTSignature(LSCT, LCert, LPubKey, 'ECDSA');
  Check(LResult = sctInvalidSignature, 'Invalid ECDSA SCT signature rejected');
end;

procedure TestFindBuiltinCTLogs;
var
  LLogID: TBytes;
  LEntry: TCTLogEntry;
begin
  WriteLn('TestFindBuiltinCTLogs');

  LLogID := TBase64Utils.Decode('DleUvPOuqT4zGyyZB7P3kN+bwj1xMiXdIaklrGHFTiE=');
  LEntry := FindCTLogByID(LLogID);
  Check(LEntry.Found, 'Google Argon2026h1 found');
  Check(LEntry.Name = 'Google Argon2026h1', 'Google Argon name');
  Check(SameBytes(LEntry.LogID, LLogID), 'Google Argon log ID matches');
  Check(SameBytes(SHA256(LEntry.PublicKeySPKI), LLogID), 'Google Argon log ID is SHA256(SPKI)');
  Check(Length(LEntry.PublicKey) = 65, 'Google Argon verifier key extracted');
  Check(LEntry.PublicKey[0] = $04, 'Google Argon verifier key is uncompressed P-256');

  LLogID := TBase64Utils.Decode('yzj3FYl8hKFEX1vB3fvJbvKaWc1HCmkFhbDLFMMUWOc=');
  LEntry := FindCTLogByID(LLogID);
  Check(LEntry.Found, 'Cloudflare Nimbus2026 found');
  Check(LEntry.Name = 'Cloudflare Nimbus2026', 'Cloudflare Nimbus name');

  LLogID := TBase64Utils.Decode('ZBHEbKQS7KeJHKICLgC8q08oB9QeNSer6v7VA8l9zfA=');
  LEntry := FindCTLogByID(LLogID);
  Check(LEntry.Found, 'DigiCert Wyvern2026h1 found');
  Check(LEntry.Name = 'DigiCert Wyvern2026h1', 'DigiCert Wyvern name');

  LLogID := TBase64Utils.Decode('fVkeEuF4KnscYWd8Xv340IdcFKBOlZ65Ay/ZDowuebg=');
  LEntry := FindCTLogByID(LLogID);
  Check(LEntry.Found, 'DigiCert Yeti2025 found');
  Check(LEntry.Name = 'DigiCert Yeti2025', 'DigiCert Yeti name');
end;

procedure TestFindUnknownCTLog;
var
  LLogID: TBytes;
  LEntry: TCTLogEntry;
begin
  WriteLn('TestFindUnknownCTLog');
  SetLength(LLogID, 32);
  FillChar(LLogID[0], Length(LLogID), $EF);

  LEntry := FindCTLogByID(LLogID);
  Check(not LEntry.Found, 'Unknown log is not found');
  Check(Length(LEntry.PublicKey) = 0, 'Unknown log has no verifier key');
end;

procedure TestVerifySCTListWithLogsEd25519Valid;
var
  LPrivateKey, LPublicKey, LCert, LSignedData, LSCTList: TBytes;
  LSCT: TSignedCertificateTimestamp;
  LResults: TSCTVerifyResultArray;
begin
  WriteLn('TestVerifySCTListWithLogsEd25519Valid');

  LPrivateKey := HexToBytes('4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb');
  LPublicKey := Ed25519PublicKeyFromPrivate(LPrivateKey);
  LCert := HexToBytes('3082010a0282010100');

  FillChar(LSCT, SizeOf(LSCT), 0);
  LSCT.Version := 0;
  LSCT.LogID := SHA256(LPublicKey);
  LSCT.Timestamp := 1704067200000;
  SetLength(LSCT.Extensions, 0);
  LSCT.HashAlgorithm := 4;
  LSCT.SignatureAlgorithm := 7;

  RegisterAdditionalCTLog('Unit Test Ed25519 Log', LSCT.LogID, LPublicKey, 'Ed25519');
  try
    LSignedData := BuildSCTSignedDataForTest(LSCT, LCert);
    Check(Ed25519Sign(LPrivateKey, LSignedData, LSCT.Signature), 'Ed25519 test SCT signed');

    LSCTList := BuildSCTList(LSCT);
    LResults := VerifySCTListWithLogs(LSCTList, LCert);
    Check(Length(LResults) = 1, 'One SCT list result returned');
    Check(LResults[0] = sctValid, 'Known Ed25519 SCT verifies with log lookup');

    LSCT.Signature[0] := LSCT.Signature[0] xor $80;
    LSCTList := BuildSCTList(LSCT);
    LResults := VerifySCTListWithLogs(LSCTList, LCert);
    Check(Length(LResults) = 1, 'One tampered SCT result returned');
    Check(LResults[0] = sctInvalidSignature, 'Tampered known SCT is invalid');
  finally
    ClearAdditionalCTLogs;
  end;
end;

procedure TestVerifySCTListWithLogsUnknown;
var
  LSCT: TSignedCertificateTimestamp;
  LCert, LSCTList: TBytes;
  LResults: TSCTVerifyResultArray;
begin
  WriteLn('TestVerifySCTListWithLogsUnknown');
  LCert := HexToBytes('3000');

  FillChar(LSCT, SizeOf(LSCT), 0);
  LSCT.Version := 0;
  SetLength(LSCT.LogID, 32);
  FillChar(LSCT.LogID[0], 32, $AA);
  LSCT.Timestamp := 1704067200000;
  SetLength(LSCT.Extensions, 0);
  LSCT.HashAlgorithm := 4;
  LSCT.SignatureAlgorithm := 7;
  SetLength(LSCT.Signature, 64);

  LSCTList := BuildSCTList(LSCT);
  LResults := VerifySCTListWithLogs(LSCTList, LCert);
  Check(Length(LResults) = 1, 'One unknown-log SCT result returned');
  Check(LResults[0] = sctUnknownLog, 'Unknown log returns sctUnknownLog');
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestParseSingleSCT;
  TestParseSCTTooShort;
  TestParseSCTWrongVersion;
  TestVerifySCTCount;
  TestVerifySCTSignatureInvalid;
  TestVerifySCTSignatureECDSAInvalid;
  TestFindBuiltinCTLogs;
  TestFindUnknownCTLog;
  TestVerifySCTListWithLogsEd25519Valid;
  TestVerifySCTListWithLogsUnknown;

  WriteLn;
  WriteLn('CT Pure tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
