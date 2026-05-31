program test_tls13_record_e2e;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.crypto.aesgcm,
  nextpas.core.tls.tls13.recordcrypto;

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

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

procedure TestEncryptDecryptRoundtrip;
var
  LKey, LIV, LNonce, LAAD: TBytes;
  LPlaintext, LInner, LCiphertext, LTag: TBytes;
  LDecrypted, LFragment: TBytes;
  LContentType: Byte;
  LSeq: QWord;
  LOk: Boolean;
begin
  LKey := HexToBytes('3fce516009c21727d0f2e4e86ee403bc');
  LIV := HexToBytes('5d313eb2671276ee13000b30');
  LSeq := 0;

  LPlaintext := HexToBytes('48656c6c6f20544c5320312e3321'); // "Hello TLS 1.3!"

  LInner := BuildTLS13InnerPlaintext(LPlaintext, $17);
  LNonce := BuildTLS13RecordNonce(LIV, LSeq);
  LAAD := BuildTLS13RecordAAD(Length(LInner) + 16);

  LOk := PurePascalAESGCMEncrypt(LKey, LNonce, LInner, LAAD, LCiphertext, LTag);
  Check('encrypt ok', LOk);
  Check('ciphertext length = inner length', Length(LCiphertext) = Length(LInner));
  Check('tag length = 16', Length(LTag) = 16);

  // Decrypt
  LOk := PurePascalAESGCMDecrypt(LKey, LNonce, LCiphertext, LTag, LAAD, LDecrypted);
  Check('decrypt ok', LOk);
  Check('decrypted = inner plaintext', BytesToHex(LDecrypted) = BytesToHex(LInner));

  // Parse inner plaintext
  LOk := TryParseTLS13InnerPlaintext(LDecrypted, LFragment, LContentType);
  Check('parse inner ok', LOk);
  Check('content type = application_data', LContentType = $17);
  Check('fragment = original plaintext', BytesToHex(LFragment) = BytesToHex(LPlaintext));
end;

procedure TestMultipleRecords;
var
  LKey, LIV, LNonce, LAAD: TBytes;
  LInner, LCiphertext, LTag, LDecrypted, LFragment: TBytes;
  LContentType: Byte;
  LSeq: QWord;
  I: Integer;
  LMsg: TBytes;
  LOk: Boolean;
begin
  LKey := HexToBytes('a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6');
  LIV := HexToBytes('112233445566778899aabbcc');
  LSeq := 0;

  for I := 0 to 4 do
  begin
    SetLength(LMsg, 10 + I * 5);
    FillChar(LMsg[0], Length(LMsg), Byte(I + $41));

    LInner := BuildTLS13InnerPlaintext(LMsg, $17);
    LNonce := BuildTLS13RecordNonce(LIV, LSeq);
    LAAD := BuildTLS13RecordAAD(Length(LInner) + 16);

    LOk := PurePascalAESGCMEncrypt(LKey, LNonce, LInner, LAAD, LCiphertext, LTag);
    if not LOk then
    begin
      Check(Format('record %d encrypt', [I]), False);
      Continue;
    end;

    LOk := PurePascalAESGCMDecrypt(LKey, LNonce, LCiphertext, LTag, LAAD, LDecrypted);
    if not LOk then
    begin
      Check(Format('record %d decrypt', [I]), False);
      Continue;
    end;

    LOk := TryParseTLS13InnerPlaintext(LDecrypted, LFragment, LContentType);
    Check(Format('record %d roundtrip', [I]), LOk and (BytesToHex(LFragment) = BytesToHex(LMsg)));

    IncrementTLS13Sequence(LSeq);
  end;
end;

procedure TestTamperedCiphertext;
var
  LKey, LIV, LNonce, LAAD: TBytes;
  LInner, LCiphertext, LTag, LDecrypted: TBytes;
  LSeq: QWord;
  LOk: Boolean;
begin
  LKey := HexToBytes('3fce516009c21727d0f2e4e86ee403bc');
  LIV := HexToBytes('5d313eb2671276ee13000b30');
  LSeq := 0;

  LInner := BuildTLS13InnerPlaintext(HexToBytes('deadbeef'), $17);
  LNonce := BuildTLS13RecordNonce(LIV, LSeq);
  LAAD := BuildTLS13RecordAAD(Length(LInner) + 16);

  PurePascalAESGCMEncrypt(LKey, LNonce, LInner, LAAD, LCiphertext, LTag);

  // Tamper with ciphertext
  if Length(LCiphertext) > 0 then
    LCiphertext[0] := LCiphertext[0] xor $FF;

  LOk := PurePascalAESGCMDecrypt(LKey, LNonce, LCiphertext, LTag, LAAD, LDecrypted);
  Check('tampered ciphertext rejected', not LOk);
end;

procedure TestTamperedAAD;
var
  LKey, LIV, LNonce, LAAD: TBytes;
  LInner, LCiphertext, LTag, LDecrypted: TBytes;
  LSeq: QWord;
  LOk: Boolean;
begin
  LKey := HexToBytes('3fce516009c21727d0f2e4e86ee403bc');
  LIV := HexToBytes('5d313eb2671276ee13000b30');
  LSeq := 0;

  LInner := BuildTLS13InnerPlaintext(HexToBytes('cafebabe'), $17);
  LNonce := BuildTLS13RecordNonce(LIV, LSeq);
  LAAD := BuildTLS13RecordAAD(Length(LInner) + 16);

  PurePascalAESGCMEncrypt(LKey, LNonce, LInner, LAAD, LCiphertext, LTag);

  // Tamper with AAD (change length field)
  LAAD[4] := LAAD[4] xor $01;

  LOk := PurePascalAESGCMDecrypt(LKey, LNonce, LCiphertext, LTag, LAAD, LDecrypted);
  Check('tampered AAD rejected', not LOk);
end;

procedure TestWrongKey;
var
  LKey, LWrongKey, LIV, LNonce, LAAD: TBytes;
  LInner, LCiphertext, LTag, LDecrypted: TBytes;
  LSeq: QWord;
  LOk: Boolean;
begin
  LKey := HexToBytes('3fce516009c21727d0f2e4e86ee403bc');
  LWrongKey := HexToBytes('ffffffffffffffffffffffffffffffff');
  LIV := HexToBytes('5d313eb2671276ee13000b30');
  LSeq := 0;

  LInner := BuildTLS13InnerPlaintext(HexToBytes('01020304'), $17);
  LNonce := BuildTLS13RecordNonce(LIV, LSeq);
  LAAD := BuildTLS13RecordAAD(Length(LInner) + 16);

  PurePascalAESGCMEncrypt(LKey, LNonce, LInner, LAAD, LCiphertext, LTag);

  LOk := PurePascalAESGCMDecrypt(LWrongKey, LNonce, LCiphertext, LTag, LAAD, LDecrypted);
  Check('wrong key rejected', not LOk);
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== TLS 1.3 Record E2E (AES-GCM) Tests ===');
  WriteLn;

  TestEncryptDecryptRoundtrip;
  TestMultipleRecords;
  TestTamperedCiphertext;
  TestTamperedAAD;
  TestWrongKey;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
