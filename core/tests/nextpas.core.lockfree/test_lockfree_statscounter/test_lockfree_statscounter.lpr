program test_lockfree_statscounter;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.lockfree.statscounter;

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

procedure TestBasicRecord;
var
  SC: TConcurrentStatsCounter;
begin
  WriteLn('--- TestBasicRecord ---');
  SC := TConcurrentStatsCounter.Create;
  try
    Check(SC.Count = 0, 'count initially 0');
    Check(SC.Sum = 0, 'sum initially 0');
    Check(SC.Min = 0, 'min initially 0');
    Check(SC.Max = 0, 'max initially 0');
    Check(SC.Mean = 0, 'mean initially 0');

    SC.RecordValue(10);
    Check(SC.Count = 1, 'count = 1');
    Check(SC.Sum = 10, 'sum = 10');
    Check(SC.Min = 10, 'min = 10');
    Check(SC.Max = 10, 'max = 10');
    Check(SC.Mean = 10, 'mean = 10');
  finally
    SC.Free;
  end;
end;

procedure TestMultipleRecords;
var
  SC: TConcurrentStatsCounter;
begin
  WriteLn('--- TestMultipleRecords ---');
  SC := TConcurrentStatsCounter.Create;
  try
    SC.RecordValue(10);
    SC.RecordValue(20);
    SC.RecordValue(30);
    SC.RecordValue(40);
    SC.RecordValue(50);

    Check(SC.Count = 5, 'count = 5');
    Check(SC.Sum = 150, 'sum = 150');
    Check(SC.Min = 10, 'min = 10');
    Check(SC.Max = 50, 'max = 50');
    Check(SC.Mean = 30, 'mean = 30');
  finally
    SC.Free;
  end;
end;

procedure TestMinMax;
var
  SC: TConcurrentStatsCounter;
begin
  WriteLn('--- TestMinMax ---');
  SC := TConcurrentStatsCounter.Create;
  try
    SC.RecordValue(100);
    SC.RecordValue(5);
    SC.RecordValue(50);
    SC.RecordValue(1);
    SC.RecordValue(200);

    Check(SC.Min = 1, 'min = 1');
    Check(SC.Max = 200, 'max = 200');
    Check(SC.Count = 5, 'count = 5');
  finally
    SC.Free;
  end;
end;

procedure TestNegativeValues;
var
  SC: TConcurrentStatsCounter;
begin
  WriteLn('--- TestNegativeValues ---');
  SC := TConcurrentStatsCounter.Create;
  try
    SC.RecordValue(-10);
    SC.RecordValue(20);
    SC.RecordValue(-5);

    Check(SC.Count = 3, 'count = 3');
    Check(SC.Sum = 5, 'sum = 5');
    Check(SC.Min = -10, 'min = -10');
    Check(SC.Max = 20, 'max = 20');
    Check(SC.Mean = 1, 'mean = 1');
  finally
    SC.Free;
  end;
end;

procedure TestReset;
var
  SC: TConcurrentStatsCounter;
begin
  WriteLn('--- TestReset ---');
  SC := TConcurrentStatsCounter.Create;
  try
    SC.RecordValue(10);
    SC.RecordValue(20);
    SC.Reset;

    Check(SC.Count = 0, 'count = 0 after reset');
    Check(SC.Sum = 0, 'sum = 0 after reset');
    Check(SC.Min = 0, 'min = 0 after reset');
    Check(SC.Max = 0, 'max = 0 after reset');
    Check(SC.Mean = 0, 'mean = 0 after reset');

    // Can record after reset
    SC.RecordValue(42);
    Check(SC.Count = 1, 'count = 1 after re-record');
    Check(SC.Sum = 42, 'sum = 42');
  finally
    SC.Free;
  end;
end;

procedure TestLargeScale;
var
  SC: TConcurrentStatsCounter;
  I, LN: Int64;
begin
  WriteLn('--- TestLargeScale ---');
  LN := 10000;
  SC := TConcurrentStatsCounter.Create;
  try
    for I := 1 to LN do
      SC.RecordValue(I);

    Check(SC.Count = LN, 'count = ' + IntToStr(LN));
    Check(SC.Sum = LN * (LN + 1) div 2, 'sum = ' + IntToStr(SC.Sum));
    Check(SC.Min = 1, 'min = 1');
    Check(SC.Max = LN, 'max = ' + IntToStr(LN));
    Check(SC.Mean = (LN + 1) div 2, 'mean');
  finally
    SC.Free;
  end;
end;

procedure TestSingleValue;
var
  SC: TConcurrentStatsCounter;
begin
  WriteLn('--- TestSingleValue ---');
  SC := TConcurrentStatsCounter.Create;
  try
    SC.RecordValue(42);
    Check(SC.Min = 42, 'min = 42');
    Check(SC.Max = 42, 'max = 42');
    Check(SC.Mean = 42, 'mean = 42');
  finally
    SC.Free;
  end;
end;

procedure TestSameValues;
var
  SC: TConcurrentStatsCounter;
  I: Integer;
begin
  WriteLn('--- TestSameValues ---');
  SC := TConcurrentStatsCounter.Create;
  try
    for I := 1 to 100 do
      SC.RecordValue(50);

    Check(SC.Count = 100, 'count = 100');
    Check(SC.Min = 50, 'min = 50');
    Check(SC.Max = 50, 'max = 50');
    Check(SC.Mean = 50, 'mean = 50');
  finally
    SC.Free;
  end;
end;

begin
  GTests := 0;
  GPassed := 0;

  TestBasicRecord;
  TestMultipleRecords;
  TestMinMax;
  TestNegativeValues;
  TestReset;
  TestLargeScale;
  TestSingleValue;
  TestSameValues;

  WriteLn;
  WriteLn(GPassed, '/', GTests, ' tests passed');
  if GPassed <> GTests then
    Halt(1);
end.
