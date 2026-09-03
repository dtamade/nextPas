program test_bigint;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.bigint,
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
  LSuite := TTestSuite.Create('bigint');

  LSuite.Test('ModExp small: 3^7 mod 13', procedure
  var LBase, LExp, LMod, LResult: TBytes; LError: string; LOk: Boolean;
  begin
    LBase := HexToBytes('03'); LExp := HexToBytes('07'); LMod := HexToBytes('0d');
    LOk := TryBigIntModExpFromUnsignedBytes(LBase, LExp, LMod, LResult, LError);
    CheckTrue(LOk); CheckEqual('03', BytesToHex(LResult));
  end);

  LSuite.Test('ModExp medium: 2^16 mod 257', procedure
  var LBase, LExp, LMod, LResult: TBytes; LError: string; LOk: Boolean;
  begin
    LBase := HexToBytes('02'); LExp := HexToBytes('10'); LMod := HexToBytes('0101');
    LOk := TryBigIntModExpFromUnsignedBytes(LBase, LExp, LMod, LResult, LError);
    CheckTrue(LOk); CheckEqual('01', BytesToHex(LResult));
  end);

  LSuite.Test('ModExp RSA-like', procedure
  var LBase, LExp, LMod, LResult, LResult2: TBytes; LError: string; LOk: Boolean;
  begin
    LBase := HexToBytes('02'); LExp := HexToBytes('010001');
    LMod := HexToBytes('FFFFFFFFFFFFFFFFFFFFFFFFFFFF0001');
    LOk := TryBigIntModExpFromUnsignedBytes(LBase, LExp, LMod, LResult, LError);
    CheckTrue(LOk);
    CheckTrue((Length(LResult) > 0) and (LResult[High(LResult)] <> 0));
    TryBigIntModExpFromUnsignedBytes(LBase, LExp, LMod, LResult2, LError);
    CheckEqual(BytesToHex(LResult), BytesToHex(LResult2));
  end);

  LSuite.Test('ModMul: 7*8 mod 13', procedure
  var LLeft, LRight, LMod, LResult: TBytes; LError: string; LOk: Boolean;
  begin
    LLeft := HexToBytes('07'); LRight := HexToBytes('08'); LMod := HexToBytes('0d');
    LOk := TryBigIntModMulFromUnsignedBytes(LLeft, LRight, LMod, LResult, LError);
    CheckTrue(LOk); CheckEqual('04', BytesToHex(LResult));
  end);

  LSuite.Test('ModSub: 3-7 mod 13', procedure
  var LLeft, LRight, LMod, LResult: TBytes; LError: string; LOk: Boolean;
  begin
    LLeft := HexToBytes('03'); LRight := HexToBytes('07'); LMod := HexToBytes('0d');
    LOk := TryBigIntSubtractModuloFromUnsignedBytes(LLeft, LRight, LMod, LResult, LError);
    CheckTrue(LOk); CheckEqual('09', BytesToHex(LResult));
  end);

  LSuite.Test('Add: 0xFF + 0x01', procedure
  var LLeft, LRight, LResult: TBytes; LError: string; LOk: Boolean;
  begin
    LLeft := HexToBytes('ff'); LRight := HexToBytes('01');
    LOk := TryBigIntAddFromUnsignedBytes(LLeft, LRight, LResult, LError);
    CheckTrue(LOk); CheckEqual('0100', BytesToHex(LResult));
  end);

  LSuite.Test('Mul: 0xFF * 0xFF', procedure
  var LLeft, LRight, LResult: TBytes; LError: string; LOk: Boolean;
  begin
    LLeft := HexToBytes('ff'); LRight := HexToBytes('ff');
    LOk := TryBigIntMulFromUnsignedBytes(LLeft, LRight, LResult, LError);
    CheckTrue(LOk); CheckEqual('fe01', BytesToHex(LResult));
  end);

  LSuite.Test('Mod: 256 mod 13', procedure
  var LValue, LMod, LResult: TBytes; LError: string; LOk: Boolean;
  begin
    LValue := HexToBytes('0100'); LMod := HexToBytes('0d');
    LOk := TryBigIntModFromUnsignedBytes(LValue, LMod, LResult, LError);
    CheckTrue(LOk); CheckEqual('09', BytesToHex(LResult));
  end);

  LSuite.Test('FixedLength: 2→4 bytes', procedure
  var LValue, LResult: TBytes; LError: string; LOk: Boolean;
  begin
    LValue := HexToBytes('0102');
    LOk := TryBigIntToFixedLengthFromUnsignedBytes(LValue, 4, LResult, LError);
    CheckTrue(LOk); CheckEqual('00000102', BytesToHex(LResult));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.bigint');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
