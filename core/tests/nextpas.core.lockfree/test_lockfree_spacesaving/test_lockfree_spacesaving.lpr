program test_lockfree_spacesaving;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.spacesaving,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

procedure TestSpaceSavingBasic;
var
  LSS: TSpaceSavingImpl;
  LResult: TSpaceSavingResult;
  LI: Integer;
begin
  LSS := TSpaceSavingImpl.Create(5);
  try
    { Add items with different frequencies }
    for LI := 1 to 100 do
      LSS.Add(1);  { Item 1: 100 times }
    for LI := 1 to 50 do
      LSS.Add(2);  { Item 2: 50 times }
    for LI := 1 to 25 do
      LSS.Add(3);  { Item 3: 25 times }

    CheckEqual(Ord(ssOk), Ord(LSS.TopK(LResult)));
    Check(LResult.FCount >= 3, 'Should have at least 3 items');

    { Most frequent should be item 1 }
    Check(LResult.FItems[0].FItem = 1, 'Top item should be 1');
    Check(LResult.FItems[0].FCount >= 100, 'Top count should be >= 100');

    SetLength(LResult.FItems, 0);
  finally
    LSS.Free;
  end;
end;

procedure TestSpaceSavingClose;
var
  LSS: TSpaceSavingImpl;
begin
  LSS := TSpaceSavingImpl.Create(10);
  try
    LSS.Add(1);
    LSS.Close;
    Check(LSS.IsClosed, 'Should be closed');
    CheckEqual(Ord(ssClosed), Ord(LSS.Add(2)));
  finally
    LSS.Free;
  end;
end;

procedure TestSpaceSavingEmpty;
var
  LSS: TSpaceSavingImpl;
  LResult: TSpaceSavingResult;
begin
  LSS := TSpaceSavingImpl.Create(5);
  try
    CheckEqual(Ord(ssEmpty), Ord(LSS.TopK(LResult)));
    CheckEqual(5, LSS.GetK);
    CheckEqual(UInt64(0), LSS.TotalItems);
  finally
    LSS.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_spacesaving ===');
  WriteLn;

  TestSpaceSavingBasic;
  WriteLn('  + Basic top-K');

  TestSpaceSavingClose;
  WriteLn('  + Close semantics');

  TestSpaceSavingEmpty;
  WriteLn('  + Empty state');

  WriteLn;
  WriteLn('All Space-Saving tests passed!');
end.
