program test_ct_bigint;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.ct.bigint,
  nextpas.core.test;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('ct_bigint');

  LSuite.Test('equal', procedure begin
    CheckTrue(CTBigIntEqual(HexToBytes('0102'), HexToBytes('0102')));
    CheckTrue(not CTBigIntEqual(HexToBytes('0102'), HexToBytes('0103')));
    CheckTrue(not CTBigIntEqual(HexToBytes('01'), HexToBytes('0102')));
  end);

  LSuite.Test('less than', procedure begin
    CheckTrue(CTBigIntLessThan(HexToBytes('01'), HexToBytes('02')));
    CheckTrue(not CTBigIntLessThan(HexToBytes('02'), HexToBytes('01')));
    CheckTrue(not CTBigIntLessThan(HexToBytes('05'), HexToBytes('05')));
    CheckTrue(CTBigIntLessThan(HexToBytes('0100'), HexToBytes('0200')));
  end);

  LSuite.Test('select', procedure
  var LA, LB, LR: TBytes;
  begin
    LA := HexToBytes('aabb'); LB := HexToBytes('ccdd');
    LR := CTBigIntSelect(True, LA, LB);
    CheckEqual('aabb', BytesToHex(LR));
    LR := CTBigIntSelect(False, LA, LB);
    CheckEqual('ccdd', BytesToHex(LR));
  end);

  LSuite.Test('conditional swap', procedure
  var LA, LB: TBytes;
  begin
    LA := HexToBytes('1111'); LB := HexToBytes('2222');
    CTBigIntConditionalSwap(True, LA, LB);
    CheckEqual('2222', BytesToHex(LA));
    CheckEqual('1111', BytesToHex(LB));
    CTBigIntConditionalSwap(False, LA, LB);
    CheckEqual('2222', BytesToHex(LA));
    CheckEqual('1111', BytesToHex(LB));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.ct.bigint');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
