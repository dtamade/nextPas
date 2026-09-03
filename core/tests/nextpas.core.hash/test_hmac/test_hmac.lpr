program test_hmac;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base.utils,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash,
  nextpas.core.crypto.hmac,
  nextpas.core.test;

function ToHex(const ABuf; ALen: Integer): string;
var I: Integer; P: PByte;
begin Result := ''; P := @ABuf;
  for I := 0 to ALen-1 do Result := Result + LowerCase(IntToHex(P[I], 2));
end;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I*2+1, 2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('hmac');

  LSuite.Test('RFC 4231 TC1', procedure
  var LKey, LData: TBytes; LD: TSHA256Digest;
  begin
    LKey := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
    LData := StringToUTF8Bytes('Hi There');
    LD := HmacSHA256(LKey, LData);
    CheckEqual('b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7',
      ToHex(LD, 32));
  end);

  LSuite.Test('RFC 4231 TC2', procedure
  var LKey, LData: TBytes; LD: TSHA256Digest;
  begin
    LKey := StringToUTF8Bytes('Jefe');
    LData := StringToUTF8Bytes('what do ya want for nothing?');
    LD := HmacSHA256(LKey, LData);
    CheckEqual('5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
      ToHex(LD, 32));
  end);

  LSuite.Test('RFC 4231 TC3', procedure
  var LKey, LData: TBytes; LD: TSHA256Digest;
  begin
    SetLength(LKey, 20); FillChar(LKey[0], 20, $AA);
    SetLength(LData, 50); FillChar(LData[0], 50, $DD);
    LD := HmacSHA256(LKey, LData);
    CheckEqual('773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe',
      ToHex(LD, 32));
  end);

  LSuite.Test('RFC 4231 TC4', procedure
  var LKey, LData: TBytes; LD: TSHA256Digest;
  begin
    LKey := HexToBytes('0102030405060708090a0b0c0d0e0f10111213141516171819');
    SetLength(LData, 50); FillChar(LData[0], 50, $CD);
    LD := HmacSHA256(LKey, LData);
    CheckEqual('82558a389a443c0ea4cc819899f2083a85f0faa3e578f8077a2e3ff46729665b',
      ToHex(LD, 32));
  end);

  LSuite.Test('RFC 4231 TC6 long key', procedure
  var LKey, LData: TBytes; LD: TSHA256Digest;
  begin
    SetLength(LKey, 131); FillChar(LKey[0], 131, $AA);
    LData := StringToUTF8Bytes('Test Using Larger Than Block-Size Key - Hash Key First');
    LD := HmacSHA256(LKey, LData);
    CheckEqual('60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54',
      ToHex(LD, 32));
  end);

  LSuite.Test('RFC 4231 TC7 long key + long data', procedure
  var LKey, LData: TBytes; LD: TSHA256Digest;
  begin
    SetLength(LKey, 131); FillChar(LKey[0], 131, $AA);
    LData := StringToUTF8Bytes('This is a test using a larger than block-size key and a larger than block-size data. ' + 'The key needs to be hashed before being used by the HMAC algorithm.');
    LD := HmacSHA256(LKey, LData);
    CheckEqual('9b09ffa71b942fcb27635fbcd5b0e944bfdc63644f0713938a7f51535c3a35e2',
      ToHex(LD, 32));
  end);

  LSuite.Test('convenience functions', procedure
  var LKey, LData, LResult: TBytes; LD: TSHA256Digest;
  begin
    LKey := StringToUTF8Bytes('secret');
    LData := StringToUTF8Bytes('message');
    LResult := HMAC_SHA256(LKey, LData);
    LD := HmacSHA256(LKey, LData);
    CheckTrue(CompareMem(@LResult[0], @LD[0], 32));
    CheckEqual(32, Length(LResult));
    LResult := HMAC_SHA384(LKey, LData);
    CheckEqual(48, Length(LResult));
    LResult := HMAC_SHA1(LKey, LData);
    CheckEqual(20, Length(LResult));
    SetLength(LData, 0);
    LResult := HMAC_SHA256(LKey, LData);
    CheckEqual(32, Length(LResult));
  end);

  LSuite.Test('streaming behavior', procedure
  var LH: IHasher; LKey, LData: TBytes; LD1, LD2: TSHA256Digest;
  begin
    LKey := StringToUTF8Bytes('Jefe');
    LData := StringToUTF8Bytes('what do ya want for nothing?');
    LH := NewHMAC(haSHA256, LKey[0], Length(LKey));
    LH.Write(LData[0], Length(LData));
    LH.Sum(LD1, 32);
    LH.Sum(LD2, 32);
    CheckTrue(CompareMem(@LD1[0], @LD2[0], 32));
    LH.Reset;
    LH.Write(LData[0], Length(LData));
    LH.Sum(LD2, 32);
    CheckTrue(CompareMem(@LD1[0], @LD2[0], 32));
    LH := NewHMAC(haSHA256, LKey[0], Length(LKey));
    LH.Write(LData[0], 5);
    LH.Write(LData[5], Length(LData) - 5);
    LH.Sum(LD2, 32);
    CheckTrue(CompareMem(@LD1[0], @LD2[0], 32));
  end);

  LSuite.Test('factory HMAC matches algo HMAC', procedure
  var LKey, LData: TBytes; H1, H2: IHasher; D1, D2: TSHA256Digest;
      F: THasherFactory;
  begin
    LKey := StringToUTF8Bytes('Jefe');
    LData := StringToUTF8Bytes('what do ya want for nothing?');
    F := function: IHasher begin Result := NewSHA256; end;
    H1 := NewHMAC(F, LKey[0], Length(LKey));
    H1.Write(LData[0], Length(LData));
    H1.Sum(D1, 32);
    H2 := NewHMAC(haSHA256, LKey[0], Length(LKey));
    H2.Write(LData[0], Length(LData));
    H2.Sum(D2, 32);
    CheckTrue(CompareMem(@D1[0], @D2[0], 32));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.hash.hmac');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
