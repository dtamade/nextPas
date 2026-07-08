program test_lockfree_cowarray;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.lockfree.cowarray;

type
  TIntCowArray = specialize TCopyOnWriteArrayImpl<Integer>;

var
  GTests, GPassed: Integer;

procedure Check(ACond: Boolean; const AName: string);
begin
  Inc(GTests);
  if ACond then
    Inc(GPassed)
  else
    WriteLn('  FAIL: ', AName);
end;

procedure TestBasicAppendGet;
var
  LArr: TIntCowArray;
  LVal: Integer;
begin
  WriteLn('--- TestBasicAppendGet ---');
  LArr := TIntCowArray.Create;
  try
    Check(LArr.IsEmpty, 'empty initially');
    Check(LArr.Count = 0, 'count = 0');
    Check(LArr.Append(42) = cowOk, 'append 42');
    Check(not LArr.IsEmpty, 'not empty');
    Check(LArr.Count = 1, 'count = 1');
    Check(LArr.Get(0, LVal) = cowOk, 'get 0');
    Check(LVal = 42, 'value = 42');
  finally
    LArr.Free;
  end;
end;

procedure TestMultipleAppend;
var
  LArr: TIntCowArray;
  LVal, I: Integer;
begin
  WriteLn('--- TestMultipleAppend ---');
  LArr := TIntCowArray.Create;
  try
    for I := 1 to 10 do
      Check(LArr.Append(I) = cowOk, 'append');
    Check(LArr.Count = 10, 'count = 10');
    for I := 0 to 9 do
    begin
      Check(LArr.Get(I, LVal) = cowOk, 'get');
      Check(LVal = I + 1, 'value');
    end;
  finally
    LArr.Free;
  end;
end;

procedure TestSetItem;
var
  LArr: TIntCowArray;
  LVal: Integer;
begin
  WriteLn('--- TestSetItem ---');
  LArr := TIntCowArray.Create;
  try
    LArr.Append(1);
    LArr.Append(2);
    LArr.Append(3);
    Check(LArr.SetItem(1, 99) = cowOk, 'set item');
    Check((LArr.Get(1, LVal) = cowOk) and (LVal = 99), 'value updated');
    // Other items unchanged
    Check((LArr.Get(0, LVal) = cowOk) and (LVal = 1), 'item 0 unchanged');
    Check((LArr.Get(2, LVal) = cowOk) and (LVal = 3), 'item 2 unchanged');
  finally
    LArr.Free;
  end;
end;

procedure TestDelete;
var
  LArr: TIntCowArray;
  LVal: Integer;
begin
  WriteLn('--- TestDelete ---');
  LArr := TIntCowArray.Create;
  try
    LArr.Append(10);
    LArr.Append(20);
    LArr.Append(30);
    Check(LArr.Delete(1) = cowOk, 'delete middle');
    Check(LArr.Count = 2, 'count = 2');
    Check((LArr.Get(0, LVal) = cowOk) and (LVal = 10), 'first unchanged');
    Check((LArr.Get(1, LVal) = cowOk) and (LVal = 30), 'last shifted');
  finally
    LArr.Free;
  end;
end;

procedure TestDeleteFirst;
var
  LArr: TIntCowArray;
  LVal: Integer;
begin
  WriteLn('--- TestDeleteFirst ---');
  LArr := TIntCowArray.Create;
  try
    LArr.Append(1);
    LArr.Append(2);
    LArr.Append(3);
    Check(LArr.Delete(0) = cowOk, 'delete first');
    Check(LArr.Count = 2, 'count = 2');
    Check((LArr.Get(0, LVal) = cowOk) and (LVal = 2), 'first shifted');
  finally
    LArr.Free;
  end;
end;

procedure TestDeleteLast;
var
  LArr: TIntCowArray;
  LVal: Integer;
begin
  WriteLn('--- TestDeleteLast ---');
  LArr := TIntCowArray.Create;
  try
    LArr.Append(1);
    LArr.Append(2);
    LArr.Append(3);
    Check(LArr.Delete(2) = cowOk, 'delete last');
    Check(LArr.Count = 2, 'count = 2');
    Check((LArr.Get(1, LVal) = cowOk) and (LVal = 2), 'last removed');
  finally
    LArr.Free;
  end;
end;

procedure TestClear;
var
  LArr: TIntCowArray;
begin
  WriteLn('--- TestClear ---');
  LArr := TIntCowArray.Create;
  try
    LArr.Append(1);
    LArr.Append(2);
    LArr.Clear;
    Check(LArr.IsEmpty, 'empty after clear');
    Check(LArr.Count = 0, 'count = 0');
    // Can still append after clear
    Check(LArr.Append(42) = cowOk, 'append after clear');
    Check(LArr.Count = 1, 'count = 1');
  finally
    LArr.Free;
  end;
end;

procedure TestIndexOutOfRange;
var
  LArr: TIntCowArray;
  LVal: Integer;
begin
  WriteLn('--- TestIndexOutOfRange ---');
  LArr := TIntCowArray.Create;
  try
    Check(LArr.Get(0, LVal) = cowIndexOutOfRange, 'get empty');
    Check(LArr.Get(-1, LVal) = cowIndexOutOfRange, 'get negative');
    LArr.Append(1);
    Check(LArr.Get(1, LVal) = cowIndexOutOfRange, 'get out of range');
    Check(LArr.SetItem(1, 99) = cowIndexOutOfRange, 'set out of range');
    Check(LArr.Delete(1) = cowIndexOutOfRange, 'delete out of range');
  finally
    LArr.Free;
  end;
end;

procedure TestClose;
var
  LArr: TIntCowArray;
begin
  WriteLn('--- TestClose ---');
  LArr := TIntCowArray.Create;
  try
    LArr.Append(1);
    LArr.Close;
    Check(LArr.IsClosed, 'is closed');
    Check(LArr.Append(2) = cowClosed, 'append after close');
    // Can still read
    Check(LArr.Count = 1, 'count still readable');
  finally
    LArr.Free;
  end;
end;

procedure TestSnapshot;
var
  LArr: TIntCowArray;
  LSnap: array of Integer;
  I: Integer;
begin
  WriteLn('--- TestSnapshot ---');
  LArr := TIntCowArray.Create;
  try
    for I := 1 to 5 do
      LArr.Append(I * 10);
    LSnap := LArr.Snapshot;
    Check(Length(LSnap) = 5, 'snapshot length');
    for I := 0 to 4 do
      Check(LSnap[I] = (I + 1) * 10, 'snapshot value');
  finally
    LArr.Free;
  end;
end;

procedure TestStrings;
var
  LArr: specialize TCopyOnWriteArrayImpl<string>;
  LVal: string;
begin
  WriteLn('--- TestStrings ---');
  LArr := specialize TCopyOnWriteArrayImpl<string>.Create;
  try
    LArr.Append('hello');
    LArr.Append('world');
    Check((LArr.Get(0, LVal) = cowOk) and (LVal = 'hello'), 'first string');
    Check((LArr.Get(1, LVal) = cowOk) and (LVal = 'world'), 'second string');
  finally
    LArr.Free;
  end;
end;

begin
  GTests := 0;
  GPassed := 0;

  TestBasicAppendGet;
  TestMultipleAppend;
  TestSetItem;
  TestDelete;
  TestDeleteFirst;
  TestDeleteLast;
  TestClear;
  TestIndexOutOfRange;
  TestClose;
  TestSnapshot;
  TestStrings;

  WriteLn;
  WriteLn(GPassed, '/', GTests, ' tests passed');
  if GPassed <> GTests then
    Halt(1);
end.
