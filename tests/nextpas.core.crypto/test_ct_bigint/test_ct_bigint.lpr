program test_ct_bigint;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.crypto.ct.bigint;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then begin WriteLn('  [PASS] ', AName); Inc(GPass); end
  else begin WriteLn('  [FAIL] ', AName); Inc(GFail); end;
end;

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

procedure TestEqual;
begin
  Check('equal: same', CTBigIntEqual(HexToBytes('0102'), HexToBytes('0102')));
  Check('equal: different', not CTBigIntEqual(HexToBytes('0102'), HexToBytes('0103')));
  Check('equal: diff length', not CTBigIntEqual(HexToBytes('01'), HexToBytes('0102')));
end;

procedure TestLessThan;
begin
  Check('lt: 01 < 02', CTBigIntLessThan(HexToBytes('01'), HexToBytes('02')));
  Check('lt: 02 not < 01', not CTBigIntLessThan(HexToBytes('02'), HexToBytes('01')));
  Check('lt: equal not <', not CTBigIntLessThan(HexToBytes('05'), HexToBytes('05')));
  // Little-endian: 0001 (=1) < 0002 (=2)
  Check('lt: 0001 < 0002 (LE)', CTBigIntLessThan(HexToBytes('0100'), HexToBytes('0200')));
end;

procedure TestSelect;
var LA, LB, LR: TBytes;
begin
  LA := HexToBytes('aabb');
  LB := HexToBytes('ccdd');
  LR := CTBigIntSelect(True, LA, LB);
  Check('select true → A', BytesToHex(LR) = 'aabb');
  LR := CTBigIntSelect(False, LA, LB);
  Check('select false → B', BytesToHex(LR) = 'ccdd');
end;

procedure TestConditionalSwap;
var LA, LB: TBytes;
begin
  LA := HexToBytes('1111');
  LB := HexToBytes('2222');
  CTBigIntConditionalSwap(True, LA, LB);
  Check('cswap true: A=2222', BytesToHex(LA) = '2222');
  Check('cswap true: B=1111', BytesToHex(LB) = '1111');

  CTBigIntConditionalSwap(False, LA, LB);
  Check('cswap false: unchanged A', BytesToHex(LA) = '2222');
  Check('cswap false: unchanged B', BytesToHex(LB) = '1111');
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== Constant-Time BigInt Tests ===');
  WriteLn;
  TestEqual;
  TestLessThan;
  TestSelect;
  TestConditionalSwap;
  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then Halt(1);
end.
