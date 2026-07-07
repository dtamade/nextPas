{**
 * @desc TBenchResultPool 测试套件
 *}
program test_bench_resultpool;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.bench.base,
  nextpas.core.bench.run,
  nextpas.core.bench.resultpool;

{ --------------------------------------------------------------------- }
{  Test Helpers }
{ --------------------------------------------------------------------- }

{ --------------------------------------------------------------------- }
{  TBenchResultPool Tests }
{ --------------------------------------------------------------------- }

procedure Test_Create_Destroy;
var
  LPool: TBenchResultPool;
begin
  LPool := TBenchResultPool.Create(16);
  try
    Check(LPool.Capacity = 16, 'capacity=16');
    Check(LPool.BorrowedCount = 0, 'borrowed=0');
  finally
    LPool.Free;
  end;
end;

procedure Test_Borrow_Single;
var
  LPool: TBenchResultPool;
  LBuf: PBenchRunResult;
begin
  LPool := TBenchResultPool.Create(16);
  try
    LBuf := LPool.Borrow;
    Check(LBuf <> nil, 'borrow returned non-nil');
    Check(LPool.BorrowedCount = 1, 'borrowed=1');
    { 不释放，让池销毁时统一释放 }
  finally
    LPool.Free;
  end;
end;

procedure Test_Borrow_Multiple;
var
  LPool: TBenchResultPool;
  LBufs: array[0..3] of PBenchRunResult;
  I: Integer;
begin
  LPool := TBenchResultPool.Create(16);
  try
    for I := 0 to 3 do
      LBufs[I] := LPool.Borrow;
    Check(LPool.BorrowedCount = 4, 'borrowed=4');
    for I := 0 to 3 do
      Check(LBufs[I] <> nil, 'buf[' + IntToStr(I) + '] non-nil');
    { 不释放，让池销毁时统一释放 }
  finally
    LPool.Free;
  end;
end;

procedure Test_Borrow_ExceedCapacity;
var
  LPool: TBenchResultPool;
  LBuf1, LBuf2: PBenchRunResult;
begin
  LPool := TBenchResultPool.Create(1);
  try
    LBuf1 := LPool.Borrow;
    Check(LBuf1 <> nil, 'first borrow ok');
    { 池满，回退到直接分配 }
    LBuf2 := LPool.Borrow;
    Check(LBuf2 <> nil, 'fallback borrow ok');
    Check(LPool.BorrowedCount = 2, 'borrowed=2');
    { 不释放，让池销毁时统一释放 }
  finally
    LPool.Free;
  end;
end;

procedure Test_BorrowedCount;
var
  LPool: TBenchResultPool;
begin
  LPool := TBenchResultPool.Create(8);
  try
    Check(LPool.BorrowedCount = 0, 'initial=0');
    LPool.Borrow;
    Check(LPool.BorrowedCount = 1, 'after 1 borrow=1');
    LPool.Borrow;
    LPool.Borrow;
    Check(LPool.BorrowedCount = 3, 'after 3 borrows=3');
  finally
    LPool.Free;
  end;
end;

procedure Test_Capacity_Default;
var
  LPool: TBenchResultPool;
begin
  LPool := TBenchResultPool.Create;
  try
    Check(LPool.Capacity = BENCH_RESULT_POOL_DEFAULT_SIZE, 'default capacity');
  finally
    LPool.Free;
  end;
end;

procedure Test_Capacity_Custom;
var
  LPool: TBenchResultPool;
begin
  LPool := TBenchResultPool.Create(32);
  try
    Check(LPool.Capacity = 32, 'custom capacity=32');
  finally
    LPool.Free;
  end;
end;

{ --------------------------------------------------------------------- }
{  Main }
{ --------------------------------------------------------------------- }

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.bench.resultpool');

  { Create / Destroy }
  T.Test('Create.Destroy', @Test_Create_Destroy);

  { Borrow }
  T.Test('Borrow.Single', @Test_Borrow_Single);
  T.Test('Borrow.Multiple', @Test_Borrow_Multiple);
  T.Test('Borrow.ExceedCapacity', @Test_Borrow_ExceedCapacity);

  { BorrowedCount }
  T.Test('BorrowedCount', @Test_BorrowedCount);

  { Capacity }
  T.Test('Capacity.Default', @Test_Capacity_Default);
  T.Test('Capacity.Custom', @Test_Capacity_Custom);

  T.Run;
  T.Summary;
end.
