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
begin
  CheckEqual(Int64(0), Int64(IndexQWord(LBuf, 2, $0102030405060708)), 'IndexQWord should find first');
  CheckEqual(Int64(1), Int64(IndexQWord(LBuf, 2, $090A0B0C0D0E0F10)), 'IndexQWord should find second');
  CheckEqual(Int64(-1), Int64(IndexQWord(LBuf, 2, $FFFFFFFFFFFFFFFF)), 'IndexQWord should return -1 for missing');
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

  if not T.Run then Halt(1);
end.
