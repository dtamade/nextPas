program test_tls13_finished;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.crypto.primitives,
  nextpas.core.tls.tls13.finished;

procedure Fail(const AMessage: string);
begin
  WriteLn('❌ ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

function HexNibble(AChar: Char): Byte;
begin
  case AChar of
    '0'..'9': Result := Ord(AChar) - Ord('0');
    'a'..'f': Result := 10 + Ord(AChar) - Ord('a');
    'A'..'F': Result := 10 + Ord(AChar) - Ord('A');
  else
    Fail('Invalid hex character: ' + AChar);
    Result := 0;
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I, LLen: Integer;
begin
  Result := nil;
  LLen := Length(AHex);
  if (LLen = 0) or ((LLen and 1) <> 0) then
    Fail('Invalid hex length');

  SetLength(Result, LLen div 2);
  for I := 0 to High(Result) do
    Result[I] := (HexNibble(AHex[2 * I + 1]) shl 4) or HexNibble(AHex[2 * I + 2]);
end;

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);

  Result := True;
  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);
end;

procedure AssertBytesEqual(const AExpected, AActual: TBytes; const AMessage: string);
begin
  if not BytesEqual(AExpected, AActual) then
    Fail(AMessage);
end;

procedure TestFinishedVector;
var
  LServerTrafficSecret: TBytes;
  LTranscriptHash: TBytes;
  LFinishedKey: TBytes;
  LVerifyData: TBytes;
begin
  LServerTrafficSecret := HexToBytes('7adbfeda325088ba2201c0175d8ea186e4d5408e3b6bd2dcb3d61f471cbf3b61');
  LTranscriptHash := HexToBytes('fc4394acdb9d481a21b9614b831016b5b5e656e5e237bc8ed8eb0eb540c2c8aa');

  LFinishedKey := TLS13FinishedKeySHA256(LServerTrafficSecret);
  AssertBytesEqual(
    HexToBytes('94275d4e6ccb8fdeae0515373eb705ce28bab307e0780fba65d22c2c8991d527'),
    LFinishedKey,
    'Finished key mismatch'
  );

  LVerifyData := TLS13ComputeFinishedVerifyDataFromTrafficSecretSHA256(LServerTrafficSecret, LTranscriptHash);
  AssertBytesEqual(
    HexToBytes('8987cbe20f79f174b8aaf0ab6d399252c30b3285eb1c71ba1b5eb6ae19f67b74'),
    LVerifyData,
    'Finished verify_data mismatch'
  );

  AssertTrue(
    TLS13VerifyFinishedSHA256(LServerTrafficSecret, LTranscriptHash, LVerifyData),
    'Finished verify should succeed'
  );

  LVerifyData[0] := LVerifyData[0] xor $01;
  AssertTrue(
    not TLS13VerifyFinishedSHA256(LServerTrafficSecret, LTranscriptHash, LVerifyData),
    'Finished verify should fail when verify_data is modified'
  );
end;

procedure TestFinishedVectorSHA384SuiteAware;
var
  LServerTrafficSecret: TBytes;
  LTranscriptHash: TBytes;
  LFinishedKey: TBytes;
  LExpectedFinishedKey: TBytes;
  LVerifyData: TBytes;
  LExpectedVerifyData: TBytes;
  LEmpty: TBytes;
begin
  LServerTrafficSecret := HexToBytes(
    '00112233445566778899aabbccddeeff' +
    '102132435465768798a9babcbddceeff' +
    '55aa55aa55aa55aa55aa55aa55aa55aa'
  );
  LTranscriptHash := HexToBytes(
    '8899aabbccddeeff0011223344556677' +
    'fedcba98765432100123456789abcdef' +
    '0102030405060708090a0b0c0d0e0f10'
  );

  SetLength(LEmpty, 0);
  LExpectedFinishedKey := TLS13_HKDF_Expand_Label_SHA384(
    LServerTrafficSecret,
    'finished',
    LEmpty,
    48
  );
  LExpectedVerifyData := HMAC_SHA384(LExpectedFinishedKey, LTranscriptHash);

  LFinishedKey := TLS13FinishedKeyForCipherSuite(
    TLS13_CIPHER_AES_256_GCM_SHA384,
    LServerTrafficSecret
  );
  AssertBytesEqual(LExpectedFinishedKey, LFinishedKey,
    'SHA384 suite-aware finished key mismatch');

  LVerifyData := TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
    TLS13_CIPHER_AES_256_GCM_SHA384,
    LServerTrafficSecret,
    LTranscriptHash
  );
  AssertBytesEqual(LExpectedVerifyData, LVerifyData,
    'SHA384 suite-aware finished verify_data mismatch');
  AssertTrue(Length(LVerifyData) = 48,
    'SHA384 suite-aware verify_data length should be 48');

  AssertTrue(
    TLS13VerifyFinishedForCipherSuite(
      TLS13_CIPHER_AES_256_GCM_SHA384,
      LServerTrafficSecret,
      LTranscriptHash,
      LVerifyData
    ),
    'SHA384 suite-aware Finished verify should succeed'
  );

  LVerifyData[0] := LVerifyData[0] xor $01;
  AssertTrue(
    not TLS13VerifyFinishedForCipherSuite(
      TLS13_CIPHER_AES_256_GCM_SHA384,
      LServerTrafficSecret,
      LTranscriptHash,
      LVerifyData
    ),
    'SHA384 suite-aware Finished verify should fail when verify_data is modified'
  );
end;

begin
  WriteLn('Testing TLS 1.3 finished verification helpers...');

  TestFinishedVector;
  TestFinishedVectorSHA384SuiteAware;

  WriteLn('✅ TLS 1.3 finished checks passed');
end.
