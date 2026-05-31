program test_tls12record;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.crypto.tls12record;

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

procedure TestSHA256_Roundtrip;
var
  LEncKey, LMACKey, LPlain, LEncrypted, LDecrypted: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LEncKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
  LMACKey := HexToBytes('aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899');
  LPlain := HexToBytes('48656c6c6f20544c5320312e3221');

  LOk := TLS12CBCEncrypt_SHA256(LEncKey, LMACKey, 0, $17, LPlain, LEncrypted, LError);
  Check('SHA256 encrypt ok', LOk);
  if not LOk then begin WriteLn('    ', LError); Exit; end;
  Check('SHA256 encrypted differs from plain', BytesToHex(LEncrypted) <> BytesToHex(LPlain));

  LOk := TLS12CBCDecrypt_SHA256(LEncKey, LMACKey, 0, $17, LEncrypted, LDecrypted, LError);
  Check('SHA256 decrypt ok', LOk);
  if not LOk then begin WriteLn('    ', LError); Exit; end;
  Check('SHA256 roundtrip', BytesToHex(LDecrypted) = BytesToHex(LPlain));
end;

procedure TestSHA384_Roundtrip;
var
  LEncKey, LMACKey, LPlain, LEncrypted, LDecrypted: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LEncKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
  LMACKey := HexToBytes('aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899');
  LPlain := HexToBytes('deadbeefcafebabe0102030405060708');

  LOk := TLS12CBCEncrypt_SHA384(LEncKey, LMACKey, 1, $17, LPlain, LEncrypted, LError);
  Check('SHA384 encrypt ok', LOk);

  LOk := TLS12CBCDecrypt_SHA384(LEncKey, LMACKey, 1, $17, LEncrypted, LDecrypted, LError);
  Check('SHA384 decrypt ok', LOk);
  if LOk then
    Check('SHA384 roundtrip', BytesToHex(LDecrypted) = BytesToHex(LPlain));
end;

procedure TestTamperedRecord;
var
  LEncKey, LMACKey, LPlain, LEncrypted, LDecrypted: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LEncKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
  LMACKey := HexToBytes('aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899');
  LPlain := HexToBytes('0102030405060708');

  TLS12CBCEncrypt_SHA256(LEncKey, LMACKey, 2, $17, LPlain, LEncrypted, LError);

  // Tamper with encrypted data
  if Length(LEncrypted) > 20 then
    LEncrypted[20] := LEncrypted[20] xor $FF;

  LOk := TLS12CBCDecrypt_SHA256(LEncKey, LMACKey, 2, $17, LEncrypted, LDecrypted, LError);
  Check('tampered record rejected', not LOk);
end;

procedure TestWrongSeqNum;
var
  LEncKey, LMACKey, LPlain, LEncrypted, LDecrypted: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LEncKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
  LMACKey := HexToBytes('aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899');
  LPlain := HexToBytes('aabbccdd');

  TLS12CBCEncrypt_SHA256(LEncKey, LMACKey, 5, $17, LPlain, LEncrypted, LError);

  // Decrypt with wrong sequence number
  LOk := TLS12CBCDecrypt_SHA256(LEncKey, LMACKey, 6, $17, LEncrypted, LDecrypted, LError);
  Check('wrong seq num rejected', not LOk);
end;

procedure TestMultipleRecords;
var
  LEncKey, LMACKey, LPlain, LEncrypted, LDecrypted: TBytes;
  LError: string;
  LOk: Boolean;
  I: Integer;
begin
  LEncKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
  LMACKey := HexToBytes('aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899');

  for I := 0 to 4 do
  begin
    SetLength(LPlain, 10 + I * 7);
    FillChar(LPlain[0], Length(LPlain), Byte(I + $30));

    LOk := TLS12CBCEncrypt_SHA256(LEncKey, LMACKey, UInt64(I), $17, LPlain, LEncrypted, LError);
    if not LOk then begin Check(Format('record %d encrypt', [I]), False); Continue; end;

    LOk := TLS12CBCDecrypt_SHA256(LEncKey, LMACKey, UInt64(I), $17, LEncrypted, LDecrypted, LError);
    Check(Format('record %d roundtrip', [I]), LOk and (BytesToHex(LDecrypted) = BytesToHex(LPlain)));
  end;
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== TLS 1.2 Record Crypto Tests ===');
  WriteLn;

  TestSHA256_Roundtrip;
  TestSHA384_Roundtrip;
  TestTamperedRecord;
  TestWrongSeqNum;
  TestMultipleRecords;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
