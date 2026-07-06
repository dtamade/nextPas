program test_system_kernel;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.system;

var
  T: TTestSuite;

{ === Swap Tests === }

procedure TestSwapWord;
var
  LValue: Word;
begin
  LValue := $1234;
  CheckEqual(Int64($3412), Int64(Swap(LValue)), 'Swap(Word) should swap bytes');
end;

procedure TestSwapSmallInt;
var
  LValue: SmallInt;
begin
  LValue := $1234;
  CheckEqual(Int64(SmallInt($3412)), Int64(Swap(LValue)), 'Swap(SmallInt) should swap bytes');
end;

procedure TestSwapDWord;
var
  LValue: DWord;
begin
  LValue := $12345678;
  { FPC Swap swaps 16-bit words, not individual bytes }
  CheckEqual(Int64($56781234), Int64(Swap(LValue)), 'Swap(DWord) should swap 16-bit words');
end;

procedure TestSwapLongInt;
var
  LValue: LongInt;
begin
  LValue := $12345678;
  CheckEqual(Int64(LongInt($56781234)), Int64(Swap(LValue)), 'Swap(LongInt) should swap 16-bit words');
end;

procedure TestSwapQWord;
var
  LValue: QWord;
begin
  LValue := $0102030405060708;
  CheckEqual(QWord($0506070801020304), Swap(LValue), 'Swap(QWord) should swap 16-bit words');
end;

procedure TestSwapInt64;
var
  LValue: Int64;
begin
  LValue := $0102030405060708;
  CheckEqual($0506070801020304, Swap(LValue), 'Swap(Int64) should swap 16-bit words');
end;

{ === Endian Tests === }

procedure TestSwapEndianWord;
var
  LValue: Word;
begin
  LValue := $1234;
  CheckEqual(Int64($3412), Int64(SwapEndian(LValue)), 'SwapEndian(Word) should swap bytes');
end;

procedure TestSwapEndianSmallInt;
var
  LValue: SmallInt;
begin
  LValue := $1234;
  CheckEqual(Int64(SmallInt($3412)), Int64(SwapEndian(LValue)), 'SwapEndian(SmallInt) should swap bytes');
end;

procedure TestSwapEndianDWord;
var
  LValue: DWord;
begin
  LValue := $12345678;
  CheckEqual(Int64($78563412), Int64(SwapEndian(LValue)), 'SwapEndian(DWord) should swap bytes');
end;

procedure TestSwapEndianLongInt;
var
  LValue: LongInt;
begin
  LValue := $12345678;
  CheckEqual(Int64(LongInt($78563412)), Int64(SwapEndian(LValue)), 'SwapEndian(LongInt) should swap bytes');
end;

procedure TestSwapEndianInt64;
var
  LValue: Int64;
begin
  LValue := $0102030405060708;
  CheckEqual($0807060504030201, SwapEndian(LValue), 'SwapEndian(Int64) should swap bytes');
end;

procedure TestSwapEndianQWord;
var
  LValue: QWord;
begin
  LValue := $0102030405060708;
  CheckEqual(QWord($0807060504030201), SwapEndian(LValue), 'SwapEndian(QWord) should swap bytes');
end;

procedure TestHTonNWord;
var
  LValue: Word;
begin
  LValue := $1234;
  { On little-endian, HTonN should swap bytes }
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64($3412), Int64(HTonN(LValue)), 'HTonN(Word) should swap on little-endian');
  {$ELSE}
  CheckEqual(Int64($1234), Int64(HTonN(LValue)), 'HTonN(Word) should not swap on big-endian');
  {$ENDIF}
end;

procedure TestHTonNLongWord;
var
  LValue: LongWord;
begin
  LValue := $12345678;
  {$IFDEF ENDIAN_LITTLE}
  { On little-endian, HTonN swaps 16-bit words (FPC Swap behavior) }
  CheckEqual(Int64($56781234), Int64(HTonN(LValue)), 'HTonN(LongWord) should swap on little-endian');
  {$ELSE}
  CheckEqual(Int64($12345678), Int64(HTonN(LValue)), 'HTonN(LongWord) should not swap on big-endian');
  {$ENDIF}
end;

procedure TestNToHsWord;
var
  LValue: Word;
begin
  LValue := $3412;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64($1234), Int64(NToHs(LValue)), 'NToHs(Word) should swap on little-endian');
  {$ELSE}
  CheckEqual(Int64($3412), Int64(NToHs(LValue)), 'NToHs(Word) should not swap on big-endian');
  {$ENDIF}
end;

procedure TestNToHsLongWord;
var
  LValue: LongWord;
begin
  LValue := $56781234;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64($12345678), Int64(NToHs(LValue)), 'NToHs(LongWord) should swap on little-endian');
  {$ELSE}
  CheckEqual(Int64($56781234), Int64(NToHs(LValue)), 'NToHs(LongWord) should not swap on big-endian');
  {$ENDIF}
end;

procedure TestBEtoNWord;
var
  LValue: Word;
begin
  LValue := $1234;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64($3412), Int64(BEtoN(LValue)), 'BEtoN(Word) should swap on little-endian');
  {$ELSE}
  CheckEqual(Int64($1234), Int64(BEtoN(LValue)), 'BEtoN(Word) should not swap on big-endian');
  {$ENDIF}
end;

procedure TestLEtoNWord;
var
  LValue: Word;
begin
  LValue := $1234;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64($1234), Int64(LEtoN(LValue)), 'LEtoN(Word) should not swap on little-endian');
  {$ELSE}
  CheckEqual(Int64($3412), Int64(LEtoN(LValue)), 'LEtoN(Word) should swap on big-endian');
  {$ENDIF}
end;

procedure TestNtoBEWord;
var
  LValue: Word;
begin
  LValue := $1234;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64($3412), Int64(NtoBE(LValue)), 'NtoBE(Word) should swap on little-endian');
  {$ELSE}
  CheckEqual(Int64($1234), Int64(NtoBE(LValue)), 'NtoBE(Word) should not swap on big-endian');
  {$ENDIF}
end;

procedure TestNtoLEWord;
var
  LValue: Word;
begin
  LValue := $1234;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64($1234), Int64(NtoLE(LValue)), 'NtoLE(Word) should not swap on little-endian');
  {$ELSE}
  CheckEqual(Int64($3412), Int64(NtoLE(LValue)), 'NtoLE(Word) should swap on big-endian');
  {$ENDIF}
end;

{ === Variant Tests === }

procedure TestVarTypeEmpty;
var
  V: Variant;
begin
  { Unassigned variant should be varEmpty }
  CheckEqual(Int64(varEmpty), Int64(VarType(V)), 'VarType should return varEmpty for unassigned variant');
end;

procedure TestVarTypeNull;
var
  V: Variant;
begin
  V := Null;
  CheckEqual(Int64(varNull), Int64(VarType(V)), 'VarType should return varNull for Null variant');
end;

procedure TestVarTypeInteger;
var
  V: Variant;
  LType: Word;
begin
  V := 42;
  LType := Word(VarType(V));
  { FPC optimizes small integers to varSmallint (16) instead of varInteger (3) }
  Check((LType = 3) or (LType = 16),
    'VarType should return varSmallint or varInteger for integer variant');
end;

procedure TestVarTypeString;
var
  V: Variant;
begin
  V := 'hello';
  CheckEqual(Int64(varString), Int64(VarType(V)), 'VarType should return varString for string variant');
end;

procedure TestVarIsNullTrue;
var
  V: Variant;
begin
  V := Null;
  Check(VarIsNull(V), 'VarIsNull should return True for Null variant');
end;

procedure TestVarIsNullFalse;
var
  V: Variant;
begin
  V := 42;
  Check(not VarIsNull(V), 'VarIsNull should return False for non-Null variant');
end;

procedure TestVarIsEmptyTrue;
var
  V: Variant;
begin
  { Unassigned variant should be empty }
  Check(VarIsEmpty(V), 'VarIsEmpty should return True for unassigned variant');
end;

procedure TestVarIsEmptyFalse;
var
  V: Variant;
begin
  V := 42;
  Check(not VarIsEmpty(V), 'VarIsEmpty should return False for assigned variant');
end;

procedure TestVarIsClearEmpty;
var
  V: Variant;
begin
  Check(VarIsClear(V), 'VarIsClear should return True for unassigned variant');
end;

procedure TestVarIsClearNull;
var
  V: Variant;
begin
  V := Null;
  Check(VarIsClear(V), 'VarIsClear should return True for Null variant');
end;

procedure TestVarIsClearAssigned;
var
  V: Variant;
begin
  V := 42;
  Check(not VarIsClear(V), 'VarIsClear should return False for assigned variant');
end;

begin
  T := TTestSuite.Create('nextpas.core.system kernel');

  { Swap tests }
  T.Test('Swap(Word)', @TestSwapWord);
  T.Test('Swap(SmallInt)', @TestSwapSmallInt);
  T.Test('Swap(DWord)', @TestSwapDWord);
  T.Test('Swap(LongInt)', @TestSwapLongInt);
  T.Test('Swap(QWord)', @TestSwapQWord);
  T.Test('Swap(Int64)', @TestSwapInt64);

  { Endian tests }
  T.Test('SwapEndian(Word)', @TestSwapEndianWord);
  T.Test('SwapEndian(SmallInt)', @TestSwapEndianSmallInt);
  T.Test('SwapEndian(DWord)', @TestSwapEndianDWord);
  T.Test('SwapEndian(LongInt)', @TestSwapEndianLongInt);
  T.Test('SwapEndian(Int64)', @TestSwapEndianInt64);
  T.Test('SwapEndian(QWord)', @TestSwapEndianQWord);
  T.Test('HTonN(Word)', @TestHTonNWord);
  T.Test('HTonN(LongWord)', @TestHTonNLongWord);
  T.Test('NToHs(Word)', @TestNToHsWord);
  T.Test('NToHs(LongWord)', @TestNToHsLongWord);
  T.Test('BEtoN(Word)', @TestBEtoNWord);
  T.Test('LEtoN(Word)', @TestLEtoNWord);
  T.Test('NtoBE(Word)', @TestNtoBEWord);
  T.Test('NtoLE(Word)', @TestNtoLEWord);

  { Variant tests }
  T.Test('VarType(empty)', @TestVarTypeEmpty);
  T.Test('VarType(null)', @TestVarTypeNull);
  T.Test('VarType(integer)', @TestVarTypeInteger);
  T.Test('VarType(string)', @TestVarTypeString);
  T.Test('VarIsNull(true)', @TestVarIsNullTrue);
  T.Test('VarIsNull(false)', @TestVarIsNullFalse);
  T.Test('VarIsEmpty(true)', @TestVarIsEmptyTrue);
  T.Test('VarIsEmpty(false)', @TestVarIsEmptyFalse);
  T.Test('VarIsClear(empty)', @TestVarIsClearEmpty);
  T.Test('VarIsClear(null)', @TestVarIsClearNull);
  T.Test('VarIsClear(assigned)', @TestVarIsClearAssigned);

  if not T.Run then Halt(1);
end.
