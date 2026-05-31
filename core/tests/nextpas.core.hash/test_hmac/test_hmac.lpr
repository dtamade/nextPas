program test_hmac;
{$mode objfpc}{$H+}
uses SysUtils, nextpas.core.hash.base, nextpas.core.hash.intf, nextpas.core.crypto.hmac;

var GPass, GFail: Integer;

procedure Check(const AName: string; ACond: Boolean);
begin
  if ACond then begin Inc(GPass); WriteLn('  [PASS] ', AName); end
  else begin Inc(GFail); WriteLn('  [FAIL] ', AName); end;
end;

function ToHex(const ABuf; ALen: Integer): string;
var I: Integer; P: PByte;
begin Result := ''; P := @ABuf;
  for I := 0 to ALen-1 do Result := Result + LowerCase(IntToHex(P[I], 2));
end;

function BytesToHex(const A: TBytes): string;
begin
  if Length(A) = 0 then Exit('');
  Result := ToHex(A[0], Length(A));
end;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I*2+1, 2));
end;

procedure TestRFC4231;
var
  LKey, LData: TBytes;
  LD256: TSHA256Digest;
begin
  WriteLn('--- RFC 4231 HMAC-SHA-256 ---');

  // TC1
  LKey := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
  LData := TEncoding.UTF8.GetBytes(UnicodeString('Hi There'));
  LD256 := HmacSHA256(LKey, LData);
  Check('TC1', ToHex(LD256, 32) = 'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7');

  // TC2
  LKey := TEncoding.UTF8.GetBytes(UnicodeString('Jefe'));
  LData := TEncoding.UTF8.GetBytes(UnicodeString('what do ya want for nothing?'));
  LD256 := HmacSHA256(LKey, LData);
  Check('TC2', ToHex(LD256, 32) = '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843');

  // TC3: key = 20 bytes of 0xaa, data = 50 bytes of 0xdd
  SetLength(LKey, 20);
  FillChar(LKey[0], 20, $AA);
  SetLength(LData, 50);
  FillChar(LData[0], 50, $DD);
  LD256 := HmacSHA256(LKey, LData);
  Check('TC3', ToHex(LD256, 32) = '773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe');

  // TC4: key = 25 bytes (01..19), data = 50 bytes of 0xcd
  LKey := HexToBytes('0102030405060708090a0b0c0d0e0f10111213141516171819');
  SetLength(LData, 50);
  FillChar(LData[0], 50, $CD);
  LD256 := HmacSHA256(LKey, LData);
  Check('TC4', ToHex(LD256, 32) = '82558a389a443c0ea4cc819899f2083a85f0faa3e578f8077a2e3ff46729665b');

  // TC6: key = 131 bytes of 0xaa (key > block size)
  SetLength(LKey, 131);
  FillChar(LKey[0], 131, $AA);
  LData := TEncoding.UTF8.GetBytes(UnicodeString('Test Using Larger Than Block-Size Key - Hash Key First'));
  LD256 := HmacSHA256(LKey, LData);
  Check('TC6 (long key)', ToHex(LD256, 32) = '60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54');

  // TC7: key = 131 bytes of 0xaa, long data
  LData := TEncoding.UTF8.GetBytes(UnicodeString(
    'This is a test using a larger than block-size key and a larger than block-size data. ' +
    'The key needs to be hashed before being used by the HMAC algorithm.'));
  LD256 := HmacSHA256(LKey, LData);
  Check('TC7 (long key + long data)', ToHex(LD256, 32) = '9b09ffa71b942fcb27635fbcd5b0e944bfdc63644f0713938a7f51535c3a35e2');
end;

procedure TestHMACConvenience;
var
  LKey, LData, LResult: TBytes;
  LD256: TSHA256Digest;
begin
  WriteLn('--- Convenience functions ---');

  LKey := TEncoding.UTF8.GetBytes(UnicodeString('secret'));
  LData := TEncoding.UTF8.GetBytes(UnicodeString('message'));

  // HMAC_SHA256 (TBytes) vs HmacSHA256 (Digest)
  LResult := HMAC_SHA256(LKey, LData);
  LD256 := HmacSHA256(LKey, LData);
  Check('HMAC_SHA256 == HmacSHA256', CompareMem(@LResult[0], @LD256[0], 32));
  Check('HMAC_SHA256 length=32', Length(LResult) = 32);

  // HMAC_SHA384
  LResult := HMAC_SHA384(LKey, LData);
  Check('HMAC_SHA384 length=48', Length(LResult) = 48);

  // HMAC_SHA1
  LResult := HMAC_SHA1(LKey, LData);
  Check('HMAC_SHA1 length=20', Length(LResult) = 20);

  // Empty data
  SetLength(LData, 0);
  LResult := HMAC_SHA256(LKey, LData);
  Check('HMAC_SHA256 empty data length=32', Length(LResult) = 32);
end;

procedure TestHMACStreaming;
var
  LH: IHasher;
  LKey, LData: TBytes;
  LD1, LD2: TSHA256Digest;
begin
  WriteLn('--- Streaming behavior ---');

  LKey := TEncoding.UTF8.GetBytes(UnicodeString('Jefe'));
  LData := TEncoding.UTF8.GetBytes(UnicodeString('what do ya want for nothing?'));

  // Sum idempotent
  LH := NewHMAC(haSHA256, LKey[0], Length(LKey));
  LH.Write(LData[0], Length(LData));
  LH.Sum(LD1, 32);
  LH.Sum(LD2, 32);
  Check('Sum idempotent', CompareMem(@LD1[0], @LD2[0], 32));

  // Reset
  LH.Reset;
  LH.Write(LData[0], Length(LData));
  LH.Sum(LD2, 32);
  Check('Reset + same data = same result', CompareMem(@LD1[0], @LD2[0], 32));

  // Incremental == one-shot
  LH := NewHMAC(haSHA256, LKey[0], Length(LKey));
  LH.Write(LData[0], 5);
  LH.Write(LData[5], Length(LData) - 5);
  LH.Sum(LD2, 32);
  Check('Incremental == one-shot', CompareMem(@LD1[0], @LD2[0], 32));
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== HMAC Tests (Enhanced) ===');
  WriteLn;

  TestRFC4231;
  TestHMACConvenience;
  TestHMACStreaming;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then Halt(1);
end.
