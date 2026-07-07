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

{ === Endian DWord/LongInt/Int64/QWord Tests === }

procedure TestBEtoNDWord;
var
  LValue: DWord;
begin
  LValue := $12345678;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64($78563412), Int64(BEtoN(LValue)), 'BEtoN(DWord) should swap on little-endian');
  {$ELSE}
  CheckEqual(Int64($12345678), Int64(BEtoN(LValue)), 'BEtoN(DWord) should not swap on big-endian');
  {$ENDIF}
end;

procedure TestLEtoNDWord;
var
  LValue: DWord;
begin
  LValue := $12345678;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64($12345678), Int64(LEtoN(LValue)), 'LEtoN(DWord) should not swap on little-endian');
  {$ELSE}
  CheckEqual(Int64($78563412), Int64(LEtoN(LValue)), 'LEtoN(DWord) should swap on big-endian');
  {$ENDIF}
end;

procedure TestNtoBEDWord;
var
  LValue: DWord;
begin
  LValue := $12345678;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64($78563412), Int64(NtoBE(LValue)), 'NtoBE(DWord) should swap on little-endian');
  {$ELSE}
  CheckEqual(Int64($12345678), Int64(NtoBE(LValue)), 'NtoBE(DWord) should not swap on big-endian');
  {$ENDIF}
end;

procedure TestNtoLEDWord;
var
  LValue: DWord;
begin
  LValue := $12345678;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64($12345678), Int64(NtoLE(LValue)), 'NtoLE(DWord) should not swap on little-endian');
  {$ELSE}
  CheckEqual(Int64($78563412), Int64(NtoLE(LValue)), 'NtoLE(DWord) should swap on big-endian');
  {$ENDIF}
end;

procedure TestBEtoNLongInt;
var
  LValue: LongInt;
begin
  LValue := $12345678;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64(LongInt($78563412)), Int64(BEtoN(LValue)), 'BEtoN(LongInt) should swap on little-endian');
  {$ELSE}
  CheckEqual(Int64($12345678), Int64(BEtoN(LValue)), 'BEtoN(LongInt) should not swap on big-endian');
  {$ENDIF}
end;

procedure TestLEtoNLongInt;
var
  LValue: LongInt;
begin
  LValue := $12345678;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64($12345678), Int64(LEtoN(LValue)), 'LEtoN(LongInt) should not swap on little-endian');
  {$ELSE}
  CheckEqual(Int64(LongInt($78563412)), Int64(LEtoN(LValue)), 'LEtoN(LongInt) should swap on big-endian');
  {$ENDIF}
end;

procedure TestNtoBELongInt;
var
  LValue: LongInt;
begin
  LValue := $12345678;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64(LongInt($78563412)), Int64(NtoBE(LValue)), 'NtoBE(LongInt) should swap on little-endian');
  {$ELSE}
  CheckEqual(Int64($12345678), Int64(NtoBE(LValue)), 'NtoBE(LongInt) should not swap on big-endian');
  {$ENDIF}
end;

procedure TestNtoLELongInt;
var
  LValue: LongInt;
begin
  LValue := $12345678;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(Int64($12345678), Int64(NtoLE(LValue)), 'NtoLE(LongInt) should not swap on little-endian');
  {$ELSE}
  CheckEqual(Int64(LongInt($78563412)), Int64(NtoLE(LValue)), 'NtoLE(LongInt) should swap on big-endian');
  {$ENDIF}
end;

procedure TestBEtoNInt64;
var
  LValue: Int64;
begin
  LValue := $0102030405060708;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual($0807060504030201, BEtoN(LValue), 'BEtoN(Int64) should swap on little-endian');
  {$ELSE}
  CheckEqual($0102030405060708, BEtoN(LValue), 'BEtoN(Int64) should not swap on big-endian');
  {$ENDIF}
end;

procedure TestLEtoNInt64;
var
  LValue: Int64;
begin
  LValue := $0102030405060708;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual($0102030405060708, LEtoN(LValue), 'LEtoN(Int64) should not swap on little-endian');
  {$ELSE}
  CheckEqual($0807060504030201, LEtoN(LValue), 'LEtoN(Int64) should swap on big-endian');
  {$ENDIF}
end;

procedure TestNtoBEInt64;
var
  LValue: Int64;
begin
  LValue := $0102030405060708;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual($0807060504030201, NtoBE(LValue), 'NtoBE(Int64) should swap on little-endian');
  {$ELSE}
  CheckEqual($0102030405060708, NtoBE(LValue), 'NtoBE(Int64) should not swap on big-endian');
  {$ENDIF}
end;

procedure TestNtoLEInt64;
var
  LValue: Int64;
begin
  LValue := $0102030405060708;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual($0102030405060708, NtoLE(LValue), 'NtoLE(Int64) should not swap on little-endian');
  {$ELSE}
  CheckEqual($0807060504030201, NtoLE(LValue), 'NtoLE(Int64) should swap on big-endian');
  {$ENDIF}
end;

procedure TestBEtoNQWord;
var
  LValue: QWord;
begin
  LValue := $0102030405060708;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(QWord($0807060504030201), BEtoN(LValue), 'BEtoN(QWord) should swap on little-endian');
  {$ELSE}
  CheckEqual(QWord($0102030405060708), BEtoN(LValue), 'BEtoN(QWord) should not swap on big-endian');
  {$ENDIF}
end;

procedure TestLEtoNQWord;
var
  LValue: QWord;
begin
  LValue := $0102030405060708;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(QWord($0102030405060708), LEtoN(LValue), 'LEtoN(QWord) should not swap on little-endian');
  {$ELSE}
  CheckEqual(QWord($0807060504030201), LEtoN(LValue), 'LEtoN(QWord) should swap on big-endian');
  {$ENDIF}
end;

procedure TestNtoBEQWord;
var
  LValue: QWord;
begin
  LValue := $0102030405060708;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(QWord($0807060504030201), NtoBE(LValue), 'NtoBE(QWord) should swap on little-endian');
  {$ELSE}
  CheckEqual(QWord($0102030405060708), NtoBE(LValue), 'NtoBE(QWord) should not swap on big-endian');
  {$ENDIF}
end;

procedure TestNtoLEQWord;
var
  LValue: QWord;
begin
  LValue := $0102030405060708;
  {$IFDEF ENDIAN_LITTLE}
  CheckEqual(QWord($0102030405060708), NtoLE(LValue), 'NtoLE(QWord) should not swap on little-endian');
  {$ELSE}
  CheckEqual(QWord($0807060504030201), NtoLE(LValue), 'NtoLE(QWord) should swap on big-endian');
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

{ === FillByte/FillDWord/FillQWord Tests === }

procedure TestFillByte;
var
  LBuf: array[0..7] of Byte;
begin
  FillByte(LBuf, SizeOf(LBuf), $AA);
  CheckEqual(Int64($AA), Int64(LBuf[0]), 'FillByte should fill first byte');
  CheckEqual(Int64($AA), Int64(LBuf[7]), 'FillByte should fill last byte');
end;

procedure TestFillDWord;
var
  LBuf: array[0..3] of DWord;
begin
  FillDWord(LBuf, Length(LBuf), $12345678);
  CheckEqual(Int64($12345678), Int64(LBuf[0]), 'FillDWord should fill first element');
  CheckEqual(Int64($12345678), Int64(LBuf[3]), 'FillDWord should fill last element');
end;

procedure TestFillQWord;
var
  LBuf: array[0..1] of QWord;
begin
  FillQWord(LBuf, Length(LBuf), $0102030405060708);
  CheckEqual($0102030405060708, LBuf[0], 'FillQWord should fill first element');
  CheckEqual($0102030405060708, LBuf[1], 'FillQWord should fill last element');
end;

{ === IndexChar/IndexByte/IndexWord/IndexDWord/IndexQWord Tests === }

procedure TestIndexChar;
var
  LBuf: array[0..4] of AnsiChar;
begin
  LBuf := 'Hello';
  CheckEqual(Int64(0), Int64(IndexChar(LBuf, 5, 'H')), 'IndexChar should find H at 0');
  CheckEqual(Int64(4), Int64(IndexChar(LBuf, 5, 'o')), 'IndexChar should find o at 4');
  CheckEqual(Int64(-1), Int64(IndexChar(LBuf, 5, 'X')), 'IndexChar should return -1 for missing');
end;

procedure TestIndexByte;
var
  LBuf: array[0..4] of Byte = (10, 20, 30, 40, 50);
begin
  CheckEqual(Int64(0), Int64(IndexByte(LBuf, 5, 10)), 'IndexByte should find 10 at 0');
  CheckEqual(Int64(4), Int64(IndexByte(LBuf, 5, 50)), 'IndexByte should find 50 at 4');
  CheckEqual(Int64(-1), Int64(IndexByte(LBuf, 5, 99)), 'IndexByte should return -1 for missing');
end;

procedure TestIndexWord;
var
  LBuf: array[0..2] of Word = ($1234, $5678, $9ABC);
begin
  CheckEqual(Int64(0), Int64(IndexWord(LBuf, 3, $1234)), 'IndexWord should find $1234 at 0');
  CheckEqual(Int64(2), Int64(IndexWord(LBuf, 3, $9ABC)), 'IndexWord should find $9ABC at 2');
  CheckEqual(Int64(-1), Int64(IndexWord(LBuf, 3, $FFFF)), 'IndexWord should return -1 for missing');
end;

procedure TestIndexDWord;
var
  LBuf: array[0..1] of DWord = ($12345678, $9ABCDEF0);
begin
  CheckEqual(Int64(0), Int64(IndexDWord(LBuf, 2, $12345678)), 'IndexDWord should find $12345678 at 0');
  CheckEqual(Int64(1), Int64(IndexDWord(LBuf, 2, $9ABCDEF0)), 'IndexDWord should find $9ABCDEF0 at 1');
  CheckEqual(Int64(-1), Int64(IndexDWord(LBuf, 2, $FFFFFFFF)), 'IndexDWord should return -1 for missing');
end;

procedure TestIndexQWord;
var
  LBuf: array[0..1] of QWord = ($0102030405060708, $090A0B0C0D0E0F10);
  LResult: Int64;
begin
  CheckEqual(Int64(0), Int64(IndexQWord(LBuf, 2, $0102030405060708)), 'IndexQWord should find first');
  CheckEqual(Int64(1), Int64(IndexQWord(LBuf, 2, $090A0B0C0D0E0F10)), 'IndexQWord should find second');
  LResult := IndexQWord(LBuf, 2, $FFFFFFFFFFFFFFFF);
  CheckEqual(Int64(-1), LResult, 'IndexQWord should return -1 for missing');
end;

{ === CompareChar/CompareByte/CompareWord/CompareDWord Tests === }

procedure TestCompareChar;
var
  LBuf1, LBuf2: array[0..4] of AnsiChar;
begin
  LBuf1 := 'Hello';
  LBuf2 := 'Hello';
  CheckEqual(Int64(0), Int64(CompareChar(LBuf1, LBuf2, 5)), 'CompareChar should return 0 for equal');
  LBuf2 := 'Hellp';
  Check(CompareChar(LBuf1, LBuf2, 5) <> 0, 'CompareChar should return non-zero for different');
end;

procedure TestCompareByte;
var
  LBuf1: array[0..2] of Byte = (1, 2, 3);
  LBuf2: array[0..2] of Byte = (1, 2, 3);
  LBuf3: array[0..2] of Byte = (1, 2, 4);
begin
  CheckEqual(Int64(0), Int64(CompareByte(LBuf1, LBuf2, 3)), 'CompareByte should return 0 for equal');
  Check(CompareByte(LBuf1, LBuf3, 3) <> 0, 'CompareByte should return non-zero for different');
end;

procedure TestCompareWord;
var
  LBuf1: array[0..1] of Word = ($1234, $5678);
  LBuf2: array[0..1] of Word = ($1234, $5678);
  LBuf3: array[0..1] of Word = ($1234, $5679);
begin
  CheckEqual(Int64(0), Int64(CompareWord(LBuf1, LBuf2, 2)), 'CompareWord should return 0 for equal');
  Check(CompareWord(LBuf1, LBuf3, 2) <> 0, 'CompareWord should return non-zero for different');
end;

procedure TestCompareDWord;
var
  LBuf1: array[0..0] of DWord = ($12345678);
  LBuf2: array[0..0] of DWord = ($12345678);
  LBuf3: array[0..0] of DWord = ($12345679);
begin
  CheckEqual(Int64(0), Int64(CompareDWord(LBuf1, LBuf2, 1)), 'CompareDWord should return 0 for equal');
  Check(CompareDWord(LBuf1, LBuf3, 1) <> 0, 'CompareDWord should return non-zero for different');
end;

{ === MoveChar0 Test === }

procedure TestMoveChar0;
var
  LSrc: array[0..5] of AnsiChar;
  LDst: array[0..9] of AnsiChar;
  I: Integer;
begin
  { Source with null terminator in the middle }
  LSrc[0] := 'H';
  LSrc[1] := 'i';
  LSrc[2] := #0;
  LSrc[3] := 'X';
  LSrc[4] := 'Y';
  LSrc[5] := 'Z';
  for I := 0 to 9 do
    LDst[I] := 'A';
  MoveChar0(LSrc, LDst, 5);
  CheckEqual(AnsiChar('H'), LDst[0], 'MoveChar0 should copy first char');
  CheckEqual(AnsiChar('i'), LDst[1], 'MoveChar0 should copy second char');
  { MoveChar0 stops at null but doesn't copy the null }
  CheckEqual(AnsiChar('A'), LDst[2], 'MoveChar0 should stop before null');
  CheckEqual(AnsiChar('A'), LDst[3], 'MoveChar0 should not copy after null');
end;

{ === MemPos Test === }

procedure TestMemPos;
var
  LHaystack: array[0..9] of Byte = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
  LNeedle1: array[0..2] of Byte = (3, 4, 5);
  LNeedle2: array[0..1] of Byte = (9, 10);
  LNeedle3: array[0..1] of Byte = (11, 12);
begin
  CheckEqual(Int64(2), Int64(MemPos(@LNeedle1[0], 3, @LHaystack[0], 10)),
    'MemPos should find needle at position 2');
  CheckEqual(Int64(8), Int64(MemPos(@LNeedle2[0], 2, @LHaystack[0], 10)),
    'MemPos should find needle at end');
  CheckEqual(Int64(-1), Int64(MemPos(@LNeedle3[0], 2, @LHaystack[0], 10)),
    'MemPos should return -1 for missing needle');
  CheckEqual(Int64(-1), Int64(MemPos(nil, 0, @LHaystack[0], 10)),
    'MemPos should return -1 for empty needle');
end;

{ === StackTop Test === }

procedure TestStackTop;
var
  LTop: Pointer;
begin
  LTop := StackTop;
  Check(LTop <> nil, 'StackTop should return non-nil pointer');
end;

{ === Memory Management Tests === }

procedure TestGetMemFreeMem;
var
  LP: Pointer;
begin
  LP := GetMem(100);
  Check(LP <> nil, 'GetMem should return non-nil pointer');
  FreeMem(LP);
end;

procedure TestGetMemZeroSize;
var
  LP: Pointer;
begin
  { FPC's GetMem(0) may return a valid pointer; just verify it doesn't crash }
  LP := GetMem(0);
  if LP <> nil then
    FreeMem(LP);
end;

procedure TestAllocMem;
var
  LP: PByte;
  I: Integer;
begin
  LP := PByte(AllocMem(100));
  Check(LP <> nil, 'AllocMem should return non-nil pointer');
  { AllocMem should zero-initialize }
  for I := 0 to 99 do
    CheckEqual(Int64(0), Int64(LP[I]), 'AllocMem should zero-initialize memory');
  FreeMem(LP);
end;

procedure TestReAllocMem;
var
  LP: Pointer;
begin
  LP := GetMem(50);
  Check(LP <> nil, 'GetMem should return non-nil');
  ReAllocMem(LP, 100);
  Check(LP <> nil, 'ReAllocMem should keep pointer non-nil');
  FreeMem(LP);
end;

procedure TestReAllocMemNil;
var
  LP: Pointer;
begin
  LP := nil;
  ReAllocMem(LP, 100);
  Check(LP <> nil, 'ReAllocMem(nil, 100) should act like GetMem');
  FreeMem(LP);
end;

procedure TestMemSize;
var
  LP: Pointer;
begin
  LP := GetMem(100);
  Check(MemSize(LP) >= 100, 'MemSize should return at least requested size');
  FreeMem(LP);
  CheckEqual(Int64(0), Int64(MemSize(nil)), 'MemSize(nil) should return 0');
end;

{ === Assigned Tests === }

procedure TestAssignedPointer;
var
  LP: Pointer;
begin
  LP := GetMem(10);
  Check(Assigned(LP), 'Assigned should return True for non-nil pointer');
  FreeMem(LP);
  Check(not Assigned(Pointer(nil)), 'Assigned should return False for nil pointer');
end;

procedure TestAssignedObject;
var
  LObj: TObject;
begin
  LObj := TObject.Create;
  try
    Check(Assigned(LObj), 'Assigned should return True for non-nil object');
  finally
    LObj.Free;
  end;
  Check(not Assigned(TObject(nil)), 'Assigned should return False for nil object');
end;

{ === Critical Section Tests === }

procedure TestCriticalSectionLifecycle;
var
  LCS: TRTLCriticalSection;
begin
  InitCriticalSection(LCS);
  EnterCriticalSection(LCS);
  LeaveCriticalSection(LCS);
  DoneCriticalSection(LCS);
end;

procedure TestCriticalSectionTryEnter;
var
  LCS: TRTLCriticalSection;
begin
  InitCriticalSection(LCS);
  { FPC's TryEnterCriticalSection returns LongInt (non-zero = success) }
  Check(TryEnterCriticalSection(LCS) <> 0, 'TryEnterCriticalSection should succeed on unlocked section');
  LeaveCriticalSection(LCS);
  DoneCriticalSection(LCS);
end;

procedure TestCriticalSectionReentrancy;
var
  LCS: TRTLCriticalSection;
begin
  InitCriticalSection(LCS);
  EnterCriticalSection(LCS);
  { FPC's critical sections are reentrant }
  EnterCriticalSection(LCS);
  LeaveCriticalSection(LCS);
  LeaveCriticalSection(LCS);
  DoneCriticalSection(LCS);
end;

{ === Interlocked Operations Tests === }

procedure TestInterlockedIncrement;
var
  LValue: LongInt;
begin
  LValue := 0;
  CheckEqual(Int64(1), Int64(InterlockedIncrement(LValue)), 'InterlockedIncrement should return 1');
  CheckEqual(Int64(1), Int64(LValue), 'InterlockedIncrement should update value');
  CheckEqual(Int64(2), Int64(InterlockedIncrement(LValue)), 'InterlockedIncrement should return 2');
  CheckEqual(Int64(2), Int64(LValue), 'InterlockedIncrement should update value');
end;

procedure TestInterlockedDecrement;
var
  LValue: LongInt;
begin
  LValue := 10;
  CheckEqual(Int64(9), Int64(InterlockedDecrement(LValue)), 'InterlockedDecrement should return 9');
  CheckEqual(Int64(9), Int64(LValue), 'InterlockedDecrement should update value');
  CheckEqual(Int64(8), Int64(InterlockedDecrement(LValue)), 'InterlockedDecrement should return 8');
  CheckEqual(Int64(8), Int64(LValue), 'InterlockedDecrement should update value');
end;

procedure TestInterlockedExchange;
var
  LValue: LongInt;
  LOld: LongInt;
begin
  LValue := 42;
  LOld := InterlockedExchange(LValue, 100);
  CheckEqual(Int64(42), Int64(LOld), 'InterlockedExchange should return old value');
  CheckEqual(Int64(100), Int64(LValue), 'InterlockedExchange should set new value');
end;

procedure TestInterlockedCompareExchange;
var
  LValue: LongInt;
  LOld: LongInt;
begin
  LValue := 42;
  { Should swap because current value (42) matches comparand (42) }
  LOld := InterlockedCompareExchange(LValue, 100, 42);
  CheckEqual(Int64(42), Int64(LOld), 'InterlockedCompareExchange should return old value');
  CheckEqual(Int64(100), Int64(LValue), 'InterlockedCompareExchange should set new value');

  { Should NOT swap because current value (100) doesn't match comparand (42) }
  LOld := InterlockedCompareExchange(LValue, 200, 42);
  CheckEqual(Int64(100), Int64(LOld), 'InterlockedCompareExchange should return current value');
  CheckEqual(Int64(100), Int64(LValue), 'InterlockedCompareExchange should not change value');
end;

procedure TestInterlockedExchangeAdd;
var
  LValue: LongInt;
  LOld: LongInt;
begin
  LValue := 10;
  LOld := InterlockedExchangeAdd(LValue, 5);
  CheckEqual(Int64(10), Int64(LOld), 'InterlockedExchangeAdd should return old value');
  CheckEqual(Int64(15), Int64(LValue), 'InterlockedExchangeAdd should add to value');
  LOld := InterlockedExchangeAdd(LValue, -3);
  CheckEqual(Int64(15), Int64(LOld), 'InterlockedExchangeAdd should return old value');
  CheckEqual(Int64(12), Int64(LValue), 'InterlockedExchangeAdd should subtract from value');
end;

{ === IO Constants Tests === }

procedure TestIOFileModeConstants;
begin
  { fmClosed/fmInput/fmOutput/fmInOut are defined in kernel.inc (nextPas path only) }
  { Under FPC, these come from System unit and have the same values }
  CheckEqual(Int64($D7B0), Int64(fmClosed), 'fmClosed should be $D7B0');
  CheckEqual(Int64($D7B1), Int64(fmInput), 'fmInput should be $D7B1');
  CheckEqual(Int64($D7B2), Int64(fmOutput), 'fmOutput should be $D7B2');
  CheckEqual(Int64($D7B3), Int64(fmInOut), 'fmInOut should be $D7B3');
end;

{ === Thread Record Size Tests === }

procedure TestTRTLCriticalSectionSize;
begin
  { TRTLCriticalSection should be a fixed-size record for mutex }
  Check(SizeOf(TRTLCriticalSection) >= 4, 'TRTLCriticalSection should be at least 4 bytes');
end;

{ === Base Type Size Verification Tests === }

procedure TestBaseTypeSizes;
begin
  CheckEqual(Int64(8), Int64(SizeOf(SizeInt)), 'SizeOf(SizeInt) should be 8');
  CheckEqual(Int64(8), Int64(SizeOf(SizeUInt)), 'SizeOf(SizeUInt) should be 8');
  CheckEqual(Int64(8), Int64(SizeOf(PtrInt)), 'SizeOf(PtrInt) should be 8');
  CheckEqual(Int64(8), Int64(SizeOf(PtrUInt)), 'SizeOf(PtrUInt) should be 8');
  CheckEqual(Int64(8), Int64(SizeOf(Pointer)), 'SizeOf(Pointer) should be 8');
  CheckEqual(Int64(1), Int64(SizeOf(Boolean)), 'SizeOf(Boolean) should be 1');
  CheckEqual(Int64(1), Int64(SizeOf(Byte)), 'SizeOf(Byte) should be 1');
  CheckEqual(Int64(2), Int64(SizeOf(Word)), 'SizeOf(Word) should be 2');
  CheckEqual(Int64(4), Int64(SizeOf(DWord)), 'SizeOf(DWord) should be 4');
  CheckEqual(Int64(4), Int64(SizeOf(LongInt)), 'SizeOf(LongInt) should be 4');
  CheckEqual(Int64(4), Int64(SizeOf(LongWord)), 'SizeOf(LongWord) should be 4');
  CheckEqual(Int64(8), Int64(SizeOf(Int64)), 'SizeOf(Int64) should be 8');
  CheckEqual(Int64(8), Int64(SizeOf(QWord)), 'SizeOf(QWord) should be 8');
  CheckEqual(Int64(1), Int64(SizeOf(AnsiChar)), 'SizeOf(AnsiChar) should be 1');
  CheckEqual(Int64(2), Int64(SizeOf(WideChar)), 'SizeOf(WideChar) should be 2');
end;

{ === TVarData Layout Tests === }

procedure TestTVarDataSize;
begin
  { FPC's TVarData is 24 bytes on x86_64 }
  CheckEqual(Int64(24), Int64(SizeOf(TVarData)), 'SizeOf(TVarData) should be 24');
end;

procedure TestTVarDataLayout;
var
  LData: TVarData;
begin
  FillChar(LData, SizeOf(LData), 0);
  LData.VType := varInteger;
  CheckEqual(Int64(varInteger), Int64(LData.VType), 'TVarData.VType should be accessible');
end;

procedure TestVariantTypeConstants;
begin
  CheckEqual(Int64(0), Int64(varEmpty), 'varEmpty should be 0');
  CheckEqual(Int64(1), Int64(varNull), 'varNull should be 1');
  CheckEqual(Int64(2), Int64(varSmallint), 'varSmallint should be 2');
  CheckEqual(Int64(3), Int64(varInteger), 'varInteger should be 3');
  CheckEqual(Int64(4), Int64(varSingle), 'varSingle should be 4');
  CheckEqual(Int64(5), Int64(varDouble), 'varDouble should be 5');
  CheckEqual(Int64(6), Int64(varCurrency), 'varCurrency should be 6');
  CheckEqual(Int64(7), Int64(varDate), 'varDate should be 7');
  CheckEqual(Int64(8), Int64(varOleStr), 'varOleStr should be 8');
  CheckEqual(Int64(9), Int64(varDispatch), 'varDispatch should be 9');
  CheckEqual(Int64(10), Int64(varError), 'varError should be 10');
  CheckEqual(Int64(11), Int64(varBoolean), 'varBoolean should be 11');
  CheckEqual(Int64(12), Int64(varVariant), 'varVariant should be 12');
  CheckEqual(Int64(13), Int64(varUnknown), 'varUnknown should be 13');
  CheckEqual(Int64(14), Int64(varDecimal), 'varDecimal should be 14');
  CheckEqual(Int64(16), Int64(varShortInt), 'varShortInt should be 16');
  CheckEqual(Int64(17), Int64(varByte), 'varByte should be 17');
  CheckEqual(Int64(18), Int64(varWord), 'varWord should be 18');
  CheckEqual(Int64(19), Int64(varLongWord), 'varLongWord should be 19');
  CheckEqual(Int64(20), Int64(varInt64), 'varInt64 should be 20');
  CheckEqual(Int64(21), Int64(varQWord), 'varQWord should be 21');
  CheckEqual(Int64($0100), Int64(varString), 'varString should be $0100');
  CheckEqual(Int64($0101), Int64(varAny), 'varAny should be $0101');
  CheckEqual(Int64($0102), Int64(varUString), 'varUString should be $0102');
end;

{ === FillMem/CopyMem/CompareMem Tests === }

procedure TestFillMem;
var
  LBuf: array[0..7] of Byte;
begin
  FillChar(LBuf, SizeOf(LBuf), 0);
  FillMem(@LBuf[0], 8, $AB);
  CheckEqual(Int64($AB), Int64(LBuf[0]), 'FillMem should fill first byte');
  CheckEqual(Int64($AB), Int64(LBuf[7]), 'FillMem should fill last byte');
end;

procedure TestCopyMem;
var
  LSrc: array[0..3] of Byte = ($11, $22, $33, $44);
  LDst: array[0..3] of Byte;
begin
  FillChar(LDst, SizeOf(LDst), 0);
  CopyMem(@LDst[0], @LSrc[0], 4);
  CheckEqual(Int64($11), Int64(LDst[0]), 'CopyMem should copy first byte');
  CheckEqual(Int64($44), Int64(LDst[3]), 'CopyMem should copy last byte');
end;

procedure TestCompareMemEqual;
var
  LA: array[0..3] of Byte = ($AA, $BB, $CC, $DD);
  LB: array[0..3] of Byte = ($AA, $BB, $CC, $DD);
begin
  CheckTrue(CompareMem(@LA[0], @LB[0], 4), 'CompareMem should return true for equal blocks');
end;

procedure TestCompareMemNotEqual;
var
  LA: array[0..3] of Byte = ($AA, $BB, $CC, $DD);
  LB: array[0..3] of Byte = ($AA, $BB, $CC, $EE);
begin
  CheckFalse(CompareMem(@LA[0], @LB[0], 4), 'CompareMem should return false for different blocks');
end;

{ === SafeFree Test === }

procedure TestSafeFree;
var
  LObj: TObject;
begin
  LObj := TObject.Create;
  SafeFree(LObj);
  CheckTrue(LObj = nil, 'SafeFree should set reference to nil');
end;

procedure TestSafeFreeNil;
var
  LObj: TObject;
begin
  LObj := nil;
  SafeFree(LObj);
  CheckTrue(LObj = nil, 'SafeFree(nil) should stay nil');
end;

{ === Assigned(IUnknown) Test === }

procedure TestAssignedInterfaceNil;
var
  LIntf: IUnknown;
begin
  LIntf := nil;
  CheckFalse(Assigned(LIntf), 'Assigned(nil interface) should return false');
end;

{ === TGUID Tests === }

procedure TestTGUIDSize;
begin
  { TGUID should be 16 bytes: D1(4) + D2(2) + D3(2) + D4(8) }
  CheckEqual(Int64(16), Int64(SizeOf(TGUID)), 'SizeOf(TGUID) should be 16');
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

  { Endian DWord/LongInt/Int64/QWord tests }
  T.Test('BEtoN(DWord)', @TestBEtoNDWord);
  T.Test('LEtoN(DWord)', @TestLEtoNDWord);
  T.Test('NtoBE(DWord)', @TestNtoBEDWord);
  T.Test('NtoLE(DWord)', @TestNtoLEDWord);
  T.Test('BEtoN(LongInt)', @TestBEtoNLongInt);
  T.Test('LEtoN(LongInt)', @TestLEtoNLongInt);
  T.Test('NtoBE(LongInt)', @TestNtoBELongInt);
  T.Test('NtoLE(LongInt)', @TestNtoLELongInt);
  T.Test('BEtoN(Int64)', @TestBEtoNInt64);
  T.Test('LEtoN(Int64)', @TestLEtoNInt64);
  T.Test('NtoBE(Int64)', @TestNtoBEInt64);
  T.Test('NtoLE(Int64)', @TestNtoLEInt64);
  T.Test('BEtoN(QWord)', @TestBEtoNQWord);
  T.Test('LEtoN(QWord)', @TestLEtoNQWord);
  T.Test('NtoBE(QWord)', @TestNtoBEQWord);
  T.Test('NtoLE(QWord)', @TestNtoLEQWord);

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

  { FillByte/FillDWord/FillQWord tests }
  T.Test('FillByte', @TestFillByte);
  T.Test('FillDWord', @TestFillDWord);
  T.Test('FillQWord', @TestFillQWord);

  { Index tests }
  T.Test('IndexChar', @TestIndexChar);
  T.Test('IndexByte', @TestIndexByte);
  T.Test('IndexWord', @TestIndexWord);
  T.Test('IndexDWord', @TestIndexDWord);
  T.Test('IndexQWord', @TestIndexQWord);

  { Compare tests }
  T.Test('CompareChar', @TestCompareChar);
  T.Test('CompareByte', @TestCompareByte);
  T.Test('CompareWord', @TestCompareWord);
  T.Test('CompareDWord', @TestCompareDWord);

  { MoveChar0 test }
  T.Test('MoveChar0', @TestMoveChar0);

  { MemPos test }
  T.Test('MemPos', @TestMemPos);

  { StackTop test }
  T.Test('StackTop', @TestStackTop);

  { Memory management tests }
  T.Test('GetMem/FreeMem', @TestGetMemFreeMem);
  T.Test('GetMem zero size', @TestGetMemZeroSize);
  T.Test('AllocMem', @TestAllocMem);
  T.Test('ReAllocMem', @TestReAllocMem);
  T.Test('ReAllocMem nil', @TestReAllocMemNil);
  T.Test('MemSize', @TestMemSize);

  { Assigned tests }
  T.Test('Assigned(pointer)', @TestAssignedPointer);
  T.Test('Assigned(object)', @TestAssignedObject);

  { Critical section tests }
  T.Test('CriticalSection lifecycle', @TestCriticalSectionLifecycle);
  T.Test('CriticalSection TryEnter', @TestCriticalSectionTryEnter);
  T.Test('CriticalSection reentrancy', @TestCriticalSectionReentrancy);

  { Interlocked tests }
  T.Test('InterlockedIncrement', @TestInterlockedIncrement);
  T.Test('InterlockedDecrement', @TestInterlockedDecrement);
  T.Test('InterlockedExchange', @TestInterlockedExchange);
  T.Test('InterlockedCompareExchange', @TestInterlockedCompareExchange);
  T.Test('InterlockedExchangeAdd', @TestInterlockedExchangeAdd);

  { IO constants tests }
  T.Test('IO file mode constants', @TestIOFileModeConstants);

  { Thread record size tests }
  T.Test('TRTLCriticalSection size', @TestTRTLCriticalSectionSize);

  { Base type size tests }
  T.Test('Base type sizes', @TestBaseTypeSizes);

  { TVarData layout tests }
  T.Test('TVarData size', @TestTVarDataSize);
  T.Test('TVarData layout', @TestTVarDataLayout);
  T.Test('Variant type constants', @TestVariantTypeConstants);

  { FillMem/CopyMem/CompareMem tests }
  T.Test('FillMem', @TestFillMem);
  T.Test('CopyMem', @TestCopyMem);
  T.Test('CompareMem equal', @TestCompareMemEqual);
  T.Test('CompareMem not equal', @TestCompareMemNotEqual);

  { SafeFree tests }
  T.Test('SafeFree', @TestSafeFree);
  T.Test('SafeFree nil', @TestSafeFreeNil);

  { Assigned interface test }
  T.Test('Assigned(interface nil)', @TestAssignedInterfaceNil);

  { TGUID tests }
  T.Test('TGUID size', @TestTGUIDSize);

  if not T.Run then Halt(1);
end.
