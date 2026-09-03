{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_persistent_vector;

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.lockfree.persistent_vector;

var
  GPassed, GFailed: Int32;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

procedure AppendAndReplace(var AVector: TPersistentVector;
  const AValue: AnsiString);
var
  LNext: TPersistentVector;
begin
  LNext := AVector.Append(AValue);
  AVector.Free;
  AVector := LNext;
end;

procedure Test_Empty;
var
  LV: TPersistentVector;
begin
  WriteLn('--- Empty ---');
  LV := TPersistentVector.Create;
  try
    Check(LV.Count = 0, 'empty count = 0');
    Check(LV.IsEmpty, 'empty IsEmpty');
    LV.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LV.Free;
    end;
  end;
end;

procedure Test_Append;
var
  LV, LV2, LV3: TPersistentVector;
  LVal: AnsiString;
begin
  WriteLn('--- Append ---');
  LV := TPersistentVector.Create;
  try
    LV2 := LV.Append('hello');
    Check(LV2.Count = 1, 'after 1 append count = 1');
    Check(LV2.Nth(0, LVal) = pvOk, 'Nth(0) = ok');
    Check(LVal = 'hello', 'Nth(0) = hello');

    LV3 := LV2.Append('world');
    Check(LV3.Count = 2, 'after 2 appends count = 2');
    Check(LV3.Nth(1, LVal) = pvOk, 'Nth(1) = ok');
    Check(LVal = 'world', 'Nth(1) = world');

    { Original vector unchanged }
    Check(LV.Count = 0, 'original still 0');
    Check(LV2.Count = 1, 'old version still 1');

    LV.Free;
    LV2.Free;
    LV3.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LV.Free;
    end;
  end;
end;

procedure Test_ManyAppends;
var
  LV: TPersistentVector;
  LPrev: TPersistentVector;
  I: Int32;
  LVal: AnsiString;
begin
  WriteLn('--- Many Appends ---');
  LV := TPersistentVector.Create;
  try
    for I := 0 to 99 do
    begin
      LPrev := LV;
      LV := LV.Append('item-' + IntToStr(I));
      LPrev.Free;
      if LV.Count <> I + 1 then
      begin
        WriteLn('  FAIL: count mismatch at ', I, ': ', LV.Count);
        Inc(GFailed);
        LV.Free;
        Exit;
      end;
    end;
    Check(LV.Count = 100, '100 appends count = 100');

    Check(LV.Nth(0, LVal) = pvOk, 'Nth(0) ok');
    Check(LVal = 'item-0', 'Nth(0) = item-0');
    Check(LV.Nth(50, LVal) = pvOk, 'Nth(50) ok');
    Check(LVal = 'item-50', 'Nth(50) = item-50');
    Check(LV.Nth(99, LVal) = pvOk, 'Nth(99) ok');
    Check(LVal = 'item-99', 'Nth(99) = item-99');

    LV.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LV.Free;
    end;
  end;
end;

procedure Test_ManyAppends_BeyondTail;
var
  LV, LPrev: TPersistentVector;
  I: Int32;
  LVal: AnsiString;
begin
  WriteLn('--- Many Appends Beyond Tail ---');
  LV := TPersistentVector.Create;
  try
    { Append 200 items to trigger tail overflow }
    for I := 0 to 199 do
    begin
      LPrev := LV;
      LV := LV.Append('k' + IntToStr(I));
      LPrev.Free;
    end;
    Check(LV.Count = 200, '200 appends count = 200');
    Check(LV.Nth(0, LVal) = pvOk, 'Nth(0) ok');
    Check(LVal = 'k0', 'Nth(0) = k0');
    Check(LV.Nth(32, LVal) = pvOk, 'Nth(32) ok');
    Check(LVal = 'k32', 'Nth(32) = k32');
    Check(LV.Nth(199, LVal) = pvOk, 'Nth(199) ok');
    Check(LVal = 'k199', 'Nth(199) = k199');

    LV.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LV.Free;
    end;
  end;
end;

procedure Test_Assoc;
var
  LV, LV2: TPersistentVector;
  LVal: AnsiString;
begin
  WriteLn('--- Assoc ---');
  LV := TPersistentVector.Create;
  try
    AppendAndReplace(LV, 'a');
    AppendAndReplace(LV, 'b');
    AppendAndReplace(LV, 'c');
    Check(LV.Count = 3, '3 appends count = 3');

    LV2 := LV.Assoc(1, 'B');
    Check(LV2 <> nil, 'Assoc(1, B) not nil');
    Check(LV2.Nth(1, LVal) = pvOk, 'Nth(1) ok');
    Check(LVal = 'B', 'Nth(1) = B');

    { Original unchanged }
    Check(LV.Nth(1, LVal) = pvOk, 'original Nth(1) ok');
    Check(LVal = 'b', 'original Nth(1) still b');

    LV.Free;
    LV2.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LV.Free;
    end;
  end;
end;

procedure Test_AssocOutOfBounds;
var
  LV, LV2: TPersistentVector;
begin
  WriteLn('--- Assoc OutOfBounds ---');
  LV := TPersistentVector.Create;
  try
    AppendAndReplace(LV, 'x');
    LV2 := LV.Assoc(5, 'y');
    Check(LV2 = nil, 'Assoc out of bounds returns nil');
    LV2 := LV.Assoc(-1, 'y');
    Check(LV2 = nil, 'Assoc negative returns nil');

    LV.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LV.Free;
    end;
  end;
end;

procedure Test_NthOutOfBounds;
var
  LV: TPersistentVector;
  LVal: AnsiString;
begin
  WriteLn('--- Nth OutOfBounds ---');
  LV := TPersistentVector.Create;
  try
    AppendAndReplace(LV, 'x');
    Check(LV.Nth(1, LVal) = pvOutOfBounds, 'Nth(1) out of bounds');
    Check(LV.Nth(-1, LVal) = pvOutOfBounds, 'Nth(-1) out of bounds');

    LV.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LV.Free;
    end;
  end;
end;

procedure Test_ToArray;
var
  LV: TPersistentVector;
  LArr: specialize TArray<AnsiString>;
  I: Int32;
begin
  WriteLn('--- ToArray ---');
  LV := TPersistentVector.Create;
  try
    for I := 0 to 4 do
      AppendAndReplace(LV, 'v' + IntToStr(I));
    LArr := LV.ToArray;
    Check(Length(LArr) = 5, 'ToArray length = 5');
    for I := 0 to 4 do
      Check(LArr[I] = 'v' + IntToStr(I), 'ToArray[' + IntToStr(I) + '] correct');

    LV.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LV.Free;
    end;
  end;
end;

procedure Test_Concat;
var
  LV1, LV2, LV3: TPersistentVector;
  LVal: AnsiString;
begin
  WriteLn('--- Concat ---');
  LV1 := TPersistentVector.Create;
  LV2 := TPersistentVector.Create;
  try
    AppendAndReplace(LV1, 'a');
    AppendAndReplace(LV1, 'b');
    AppendAndReplace(LV2, 'c');
    AppendAndReplace(LV2, 'd');

    LV3 := LV1.Concat(LV2);
    Check(LV3.Count = 4, 'concat count = 4');
    Check(LV3.Nth(0, LVal) = pvOk, 'concat Nth(0) ok');
    Check(LVal = 'a', 'concat Nth(0) = a');
    Check(LV3.Nth(2, LVal) = pvOk, 'concat Nth(2) ok');
    Check(LVal = 'c', 'concat Nth(2) = c');
    Check(LV3.Nth(3, LVal) = pvOk, 'concat Nth(3) ok');
    Check(LVal = 'd', 'concat Nth(3) = d');

    LV1.Free;
    LV2.Free;
    LV3.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LV1.Free;
      LV2.Free;
    end;
  end;
end;

procedure Test_Immutability;
var
  LV1, LV2, LV3: TPersistentVector;
  LVal: AnsiString;
begin
  WriteLn('--- Immutability ---');
  LV1 := TPersistentVector.Create;
  try
    LV2 := LV1.Append('first');
    LV3 := LV2.Append('second');

    { All versions should be independent }
    Check(LV1.Count = 0, 'v1 count = 0');
    Check(LV2.Count = 1, 'v2 count = 1');
    Check(LV3.Count = 2, 'v3 count = 2');

    Check(LV2.Nth(0, LVal) = pvOk, 'v2 Nth(0) ok');
    Check(LVal = 'first', 'v2 Nth(0) = first');
    Check(LV3.Nth(0, LVal) = pvOk, 'v3 Nth(0) ok');
    Check(LVal = 'first', 'v3 Nth(0) = first');
    Check(LV3.Nth(1, LVal) = pvOk, 'v3 Nth(1) ok');
    Check(LVal = 'second', 'v3 Nth(1) = second');

    LV1.Free;
    LV2.Free;
    LV3.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LV1.Free;
    end;
  end;
end;

procedure Test_CowPathCopyAndReleaseOrder;
var
  LBase, LNext, LLeftBranch, LRightBranch, LAppended: TPersistentVector;
  LI: Int32;
  LValue: AnsiString;
begin
  WriteLn('--- COW Path Copy And Release Order ---');
  LBase := TPersistentVector.Create;
  LLeftBranch := nil;
  LRightBranch := nil;
  LAppended := nil;
  try
    for LI := 0 to 69 do
    begin
      LNext := LBase.Append('v' + IntToStr(LI));
      LBase.Free;
      LBase := LNext;
    end;

    LLeftBranch := LBase.Assoc(0, 'left');
    LRightBranch := LBase.Assoc(69, 'right');
    LAppended := LLeftBranch.Append('tail');

    LBase.Free;
    LBase := nil;
    Check(LLeftBranch.Nth(69, LValue) = pvOk,
      'Left branch remains readable after base release');
    Check(LValue = 'v69', 'Unmodified tail chunk remains intact');
    Check(LRightBranch.Nth(0, LValue) = pvOk,
      'Right branch remains readable after base release');
    Check(LValue = 'v0', 'Unmodified head chunk remains intact');

    LLeftBranch.Free;
    LLeftBranch := nil;
    Check(LAppended.Nth(0, LValue) = pvOk,
      'Appended version survives parent release');
    Check(LValue = 'left', 'Copied head path keeps branch update');
    Check(LAppended.Nth(70, LValue) = pvOk,
      'Appended version exposes new tail');
    Check(LValue = 'tail', 'New tail value is intact');
  finally
    LBase.Free;
    LLeftBranch.Free;
    LRightBranch.Free;
    LAppended.Free;
  end;
end;

procedure Test_CowImplementationContract;
var
  LSource: string;
  LText: AnsiString;
begin
  WriteLn('--- COW Implementation Contract ---');
  LSource := ReadFileText('../../../src/nextpas.core.lockfree.persistent_vector.pas');
    LText := LSource;
    Check(Pos('PVectorChunk', LText) > 0,
      'Persistent vector stores reference-counted chunks');
    Check(Pos('RefCount: Int32', LText) > 0,
      'Chunk ownership has an explicit reference count');
    Check(Pos('RetainChunk', LText) > 0,
      'Unchanged chunks are retained across versions');
    Check(Pos('ReleaseChunk', LText) > 0,
      'Old versions release shared chunks');
    Check(Pos('CloneChunk', LText) > 0,
      'Only the modified chunk is cloned');
end;

begin
  GPassed := 0;
  GFailed := 0;
  WriteLn('=== PersistentVector Tests ===');
  Test_Empty;
  Test_Append;
  Test_ManyAppends;
  Test_ManyAppends_BeyondTail;
  Test_Assoc;
  Test_AssocOutOfBounds;
  Test_NthOutOfBounds;
  Test_ToArray;
  Test_Concat;
  Test_Immutability;
  Test_CowPathCopyAndReleaseOrder;
  Test_CowImplementationContract;
  WriteLn;
  WriteLn('Results: ', GPassed, ' passed, ', GFailed, ' failed');
  if GFailed > 0 then
    Halt(1);
end.
