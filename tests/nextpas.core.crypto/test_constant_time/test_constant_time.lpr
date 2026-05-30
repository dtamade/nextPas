program test_constant_time;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.crypto.constant_time;

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

procedure TestCompareBytes_Equal;
var
  LA, LB: TBytes;
begin
  LA := HexToBytes('0102030405060708');
  LB := HexToBytes('0102030405060708');
  Check('CompareBytes equal → 1', TConstantTime.CompareBytes(LA, LB) = 1);
end;

procedure TestCompareBytes_Different;
var
  LA, LB: TBytes;
begin
  LA := HexToBytes('0102030405060708');
  LB := HexToBytes('0102030405060709');
  Check('CompareBytes different → 0', TConstantTime.CompareBytes(LA, LB) = 0);
end;

procedure TestCompareBytes_DifferentLength;
var
  LA, LB: TBytes;
begin
  LA := HexToBytes('010203');
  LB := HexToBytes('01020304');
  Check('CompareBytes diff length → 0', TConstantTime.CompareBytes(LA, LB) = 0);
end;

procedure TestCompareBytes_Empty;
var
  LA, LB: TBytes;
begin
  SetLength(LA, 0);
  SetLength(LB, 0);
  Check('CompareBytes both empty → 1', TConstantTime.CompareBytes(LA, LB) = 1);
end;

procedure TestCompareBuffer;
var
  LA, LB: array[0..7] of Byte;
begin
  FillChar(LA, 8, $AA);
  FillChar(LB, 8, $AA);
  Check('CompareBuffer equal → 1', TConstantTime.CompareBuffer(@LA[0], @LB[0], 8) = 1);

  LB[7] := $BB;
  Check('CompareBuffer different → 0', TConstantTime.CompareBuffer(@LA[0], @LB[0], 8) = 0);
end;

procedure TestCompareStrings;
begin
  Check('CompareStrings equal', TConstantTime.CompareStrings('hello', 'hello'));
  Check('CompareStrings different', not TConstantTime.CompareStrings('hello', 'world'));
  Check('CompareStrings diff length', not TConstantTime.CompareStrings('hi', 'hello'));
  Check('CompareStrings empty', TConstantTime.CompareStrings('', ''));
end;

procedure TestSelect;
var
  LTrue, LFalse, LResult: TBytes;
begin
  LTrue := HexToBytes('aabbccdd');
  LFalse := HexToBytes('11223344');

  LResult := TConstantTime.Select(1, LTrue, LFalse);
  Check('Select(1) → IfTrue', (LResult[0] = $AA) and (LResult[3] = $DD));

  LResult := TConstantTime.Select(0, LTrue, LFalse);
  Check('Select(0) → IfFalse', (LResult[0] = $11) and (LResult[3] = $44));
end;

procedure TestIsZero;
begin
  Check('IsZero(0) → 1', TConstantTime.IsZero(0) = 1);
  Check('IsZero(1) → 0', TConstantTime.IsZero(1) = 0);
  Check('IsZero(255) → 0', TConstantTime.IsZero(255) = 0);
  Check('IsZero(128) → 0', TConstantTime.IsZero(128) = 0);
end;

procedure TestIsZeroInt;
begin
  Check('IsZeroInt(0) → 1', TConstantTime.IsZeroInt(0) = 1);
  Check('IsZeroInt(1) → 0', TConstantTime.IsZeroInt(1) = 0);
  Check('IsZeroInt(-1) → 0', TConstantTime.IsZeroInt(-1) = 0);
  Check('IsZeroInt(MaxInt) → 0', TConstantTime.IsZeroInt(MaxInt) = 0);
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== Constant-Time Operations Tests ===');
  WriteLn;

  TestCompareBytes_Equal;
  TestCompareBytes_Different;
  TestCompareBytes_DifferentLength;
  TestCompareBytes_Empty;
  TestCompareBuffer;
  TestCompareStrings;
  TestSelect;
  TestIsZero;
  TestIsZeroInt;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
