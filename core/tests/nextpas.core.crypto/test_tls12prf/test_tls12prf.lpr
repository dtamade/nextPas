program test_tls12prf;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.tls12prf,
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
  LSuite := TTestSuite.Create('tls12prf');

  LSuite.Test('PRF-SHA256 master secret', procedure
  var LPreMaster, LSeed, LResult: TBytes;
  begin
    LPreMaster := HexToBytes('03033b46a7c4f230d5d5e4d5ab2a2f5cf4f8e6a3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3');
    LSeed := HexToBytes('5bc0b19b4a8b24b07afe7ec65c6e3b96b1f3523c4aef1c0d2bb600cb27f5f818');
    LResult := TLS12PRF_SHA256(LPreMaster, 'master secret', LSeed, 48);
    CheckEqual(48, Length(LResult));
    CheckTrue(BytesToHex(LResult) <> TextOfChar('0', 96));
  end);

  LSuite.Test('PRF-SHA256 key expansion', procedure
  var LMaster, LSeed, LResult: TBytes;
  begin
    LMaster := HexToBytes('ab1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcd');
    LSeed := HexToBytes('aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd11223344');
    LResult := TLS12PRF_SHA256(LMaster, 'key expansion', LSeed, 104);
    CheckEqual(104, Length(LResult));
  end);

  LSuite.Test('PRF-SHA256 RFC5246 vector', procedure
  var LSecret, LSeed, LResult: TBytes;
  begin
    LSecret := HexToBytes('9bbe436ba940f017b17652849a71db35');
    LSeed := HexToBytes('a0ba9f936cda311827a6f796ffd5198c');
    LResult := TLS12PRF_SHA256(LSecret, 'test label', LSeed, 100);
    CheckEqual(100, Length(LResult));
    LResult := TLS12PRF_SHA256(LSecret, 'test label', LSeed, 32);
    CheckEqual(32, Length(LResult));
    CheckEqual(BytesToHex(LResult),
      BytesToHex(TLS12PRF_SHA256(LSecret, 'test label', LSeed, 32)));
  end);

  LSuite.Test('PRF-SHA384', procedure
  var LSecret, LSeed, LResult: TBytes;
  begin
    LSecret := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
    LSeed := HexToBytes('aabbccdd11223344');
    LResult := TLS12PRF_SHA384(LSecret, 'test label', LSeed, 48);
    CheckEqual(48, Length(LResult));
    LResult := TLS12PRF_SHA384(LSecret, 'test label', LSeed, 128);
    CheckEqual(128, Length(LResult));
  end);

  LSuite.Test('PRF-SHA256 OpenSSL vector', procedure
  var LSecret, LSeed, LResult: TBytes;
  begin
    LSecret := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
    LSeed := HexToBytes('73656564');
    LResult := TLS12PRF_SHA256(LSecret, 'test label', LSeed, 32);
    CheckEqual(32, Length(LResult));
    CheckEqual('72c350bc08df2a9dfede75c55a1612281929c452d032b6905f95304b92684d1b', BytesToHex(LResult));
  end);

  LSuite.Test('PRF label byte copy', procedure
  var LSecret, LSeed, LR1, LR2: TBytes; LLabel: string;
  begin
    LSecret := HexToBytes('00112233445566778899aabbccddeeff');
    LSeed := HexToBytes('0102030405060708');
    LLabel := 'tls' + #0 + #$E9 + 'label';
    LR1 := TLS12PRF_SHA256(LSecret, LLabel, LSeed, 32);
    LR2 := TLS12PRF_SHA256(LSecret, LLabel, LSeed, 32);
    CheckEqual(32, Length(LR1));
    CheckEqual(BytesToHex(LR1), BytesToHex(LR2));
    CheckTrue(BytesToHex(LR1) <> BytesToHex(TLS12PRF_SHA256(LSecret, 'tlslabel', LSeed, 32)));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.tls12prf');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
