program test_tls12record;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.tls12record,
  nextpas.core.test;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do Result[I] := StrToInt('$' + Copy(AHex, I*2+1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var I: Integer;
begin Result := '';
  for I := 0 to High(AData) do Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('tls12record');

  LSuite.Test('SHA256 roundtrip', procedure
  var LEncKey, LMACKey, LPlain, LEncrypted, LDecrypted: TBytes; LError: string; LOk: Boolean;
  begin
    LEncKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LMACKey := HexToBytes('aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899');
    LPlain := HexToBytes('48656c6c6f20544c5320312e3221');
    LOk := TLS12CBCEncrypt_SHA256(LEncKey, LMACKey, 0, $17, LPlain, LEncrypted, LError);
    CheckTrue(LOk);
    CheckTrue(BytesToHex(LEncrypted) <> BytesToHex(LPlain));
    LOk := TLS12CBCDecrypt_SHA256(LEncKey, LMACKey, 0, $17, LEncrypted, LDecrypted, LError);
    CheckTrue(LOk);
    CheckEqual(BytesToHex(LPlain), BytesToHex(LDecrypted));
  end);

  LSuite.Test('SHA384 roundtrip', procedure
  var LEncKey, LMACKey, LPlain, LEncrypted, LDecrypted: TBytes; LError: string; LOk: Boolean;
  begin
    LEncKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LMACKey := HexToBytes('aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899');
    LPlain := HexToBytes('deadbeefcafebabe0102030405060708');
    LOk := TLS12CBCEncrypt_SHA384(LEncKey, LMACKey, 1, $17, LPlain, LEncrypted, LError);
    CheckTrue(LOk);
    LOk := TLS12CBCDecrypt_SHA384(LEncKey, LMACKey, 1, $17, LEncrypted, LDecrypted, LError);
    CheckTrue(LOk);
    CheckEqual(BytesToHex(LPlain), BytesToHex(LDecrypted));
  end);

  LSuite.Test('tampered record rejected', procedure
  var LEncKey, LMACKey, LPlain, LEncrypted, LDecrypted: TBytes; LError: string; LOk: Boolean;
  begin
    LEncKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LMACKey := HexToBytes('aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899');
    LPlain := HexToBytes('0102030405060708');
    TLS12CBCEncrypt_SHA256(LEncKey, LMACKey, 2, $17, LPlain, LEncrypted, LError);
    if Length(LEncrypted) > 20 then LEncrypted[20] := LEncrypted[20] xor $FF;
    LOk := TLS12CBCDecrypt_SHA256(LEncKey, LMACKey, 2, $17, LEncrypted, LDecrypted, LError);
    CheckTrue(not LOk);
  end);

  LSuite.Test('wrong seq num rejected', procedure
  var LEncKey, LMACKey, LPlain, LEncrypted, LDecrypted: TBytes; LError: string; LOk: Boolean;
  begin
    LEncKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LMACKey := HexToBytes('aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899');
    LPlain := HexToBytes('aabbccdd');
    TLS12CBCEncrypt_SHA256(LEncKey, LMACKey, 5, $17, LPlain, LEncrypted, LError);
    LOk := TLS12CBCDecrypt_SHA256(LEncKey, LMACKey, 6, $17, LEncrypted, LDecrypted, LError);
    CheckTrue(not LOk);
  end);

  LSuite.Test('multiple records', procedure
  var LEncKey, LMACKey, LPlain, LEncrypted, LDecrypted: TBytes; LError: string; LOk: Boolean; I: Integer;
  begin
    LEncKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LMACKey := HexToBytes('aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899');
    for I := 0 to 4 do begin
      SetLength(LPlain, 10 + I * 7);
      FillChar(LPlain[0], Length(LPlain), Byte(I + $30));
      LOk := TLS12CBCEncrypt_SHA256(LEncKey, LMACKey, UInt64(I), $17, LPlain, LEncrypted, LError);
      if not LOk then begin CheckTrue(False); Continue; end;
      LOk := TLS12CBCDecrypt_SHA256(LEncKey, LMACKey, UInt64(I), $17, LEncrypted, LDecrypted, LError);
      CheckTrue(LOk and (BytesToHex(LDecrypted) = BytesToHex(LPlain)));
    end;
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.tls12record');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
