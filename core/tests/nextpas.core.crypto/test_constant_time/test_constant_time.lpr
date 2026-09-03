program test_constant_time;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.constant_time,
  nextpas.core.test;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('constant_time');

  LSuite.Test('CompareBytes equal', procedure
  var LA, LB: TBytes;
  begin
    LA := HexToBytes('0102030405060708');
    LB := HexToBytes('0102030405060708');
    CheckEqual(1, TConstantTime.CompareBytes(LA, LB));
  end);

  LSuite.Test('CompareBytes different', procedure
  var LA, LB: TBytes;
  begin
    LA := HexToBytes('0102030405060708');
    LB := HexToBytes('0102030405060709');
    CheckEqual(0, TConstantTime.CompareBytes(LA, LB));
  end);

  LSuite.Test('CompareBytes different length', procedure
  var LA, LB: TBytes;
  begin
    LA := HexToBytes('010203');
    LB := HexToBytes('01020304');
    CheckEqual(0, TConstantTime.CompareBytes(LA, LB));
  end);

  LSuite.Test('CompareBytes empty', procedure
  var LA, LB: TBytes;
  begin
    SetLength(LA, 0); SetLength(LB, 0);
    CheckEqual(1, TConstantTime.CompareBytes(LA, LB));
  end);

  LSuite.Test('CompareBuffer', procedure
  var LA, LB: array[0..7] of Byte;
  begin
    FillChar(LA, 8, $AA); FillChar(LB, 8, $AA);
    CheckEqual(1, TConstantTime.CompareBuffer(@LA[0], @LB[0], 8));
    LB[7] := $BB;
    CheckEqual(0, TConstantTime.CompareBuffer(@LA[0], @LB[0], 8));
  end);

  LSuite.Test('CompareStrings', procedure begin
    CheckTrue(TConstantTime.CompareStrings('hello', 'hello'));
    CheckTrue(not TConstantTime.CompareStrings('hello', 'world'));
    CheckTrue(not TConstantTime.CompareStrings('hi', 'hello'));
    CheckTrue(TConstantTime.CompareStrings('', ''));
  end);

  LSuite.Test('Select', procedure
  var LTrue, LFalse, LResult: TBytes;
  begin
    LTrue := HexToBytes('aabbccdd');
    LFalse := HexToBytes('11223344');
    LResult := TConstantTime.Select(1, LTrue, LFalse);
    CheckTrue((LResult[0] = $AA) and (LResult[3] = $DD));
    LResult := TConstantTime.Select(0, LTrue, LFalse);
    CheckTrue((LResult[0] = $11) and (LResult[3] = $44));
  end);

  LSuite.Test('IsZero', procedure begin
    CheckEqual(1, TConstantTime.IsZero(0));
    CheckEqual(0, TConstantTime.IsZero(1));
    CheckEqual(0, TConstantTime.IsZero(255));
    CheckEqual(0, TConstantTime.IsZero(128));
  end);

  LSuite.Test('IsZeroInt', procedure begin
    CheckEqual(1, TConstantTime.IsZeroInt(0));
    CheckEqual(0, TConstantTime.IsZeroInt(1));
    CheckEqual(0, TConstantTime.IsZeroInt(-1));
    CheckEqual(0, TConstantTime.IsZeroInt(MaxInt));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.constant_time');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
