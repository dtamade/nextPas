program test_object_pool;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.testing,
  nextpas.core.mem.error,
  nextpas.core.mem.pool,
  nextpas.core.mem.pool.object_pool;

type
  TTestObject = class
    Value: Integer;
  end;

  TTestPool = specialize TObjectPool<TTestObject>;

var
  T: TTestRunner;

procedure TestCreateAndDestroy;
var
  LPool: TTestPool;
begin
  LPool := TTestPool.Create(5,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end);
  try
    CheckEqual(Int64(5), Int64(LPool.MaxObjects), 'max objects');
    CheckEqual(Int64(0), Int64(LPool.InPoolCount), 'initial in-pool');
    CheckEqual(Int64(0), Int64(LPool.TotalCreated), 'initial total created');
  finally
    LPool.Free;
  end;
  WriteLn('PASS: Create/Destroy lifecycle');
end;

procedure TestAcquireReturnsValidObject;
var
  LPool: TTestPool;
  LObj: TTestObject;
begin
  LPool := TTestPool.Create(3,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end);
  try
    Check(LPool.AcquireObject(LObj), 'acquire succeeds');
    Check(LObj <> nil, 'object not nil');
    CheckEqual(Int64(1), Int64(LPool.TotalCreated), 'total created = 1');
    LPool.ReleaseObject(LObj);
  finally
    LPool.Free;
  end;
  WriteLn('PASS: Acquire returns valid object');
end;

procedure TestReleaseAndReacquire;
var
  LPool: TTestPool;
  LObj, LObj2: TTestObject;
begin
  LPool := TTestPool.Create(3,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end);
  try
    Check(LPool.AcquireObject(LObj), 'first acquire');
    LPool.ReleaseObject(LObj);
    CheckEqual(Int64(1), Int64(LPool.InPoolCount), 'in-pool after release');

    Check(LPool.AcquireObject(LObj2), 'reacquire');
    CheckEqual(Int64(0), Int64(LPool.InPoolCount), 'in-pool after reacquire');
    Check(LObj = LObj2, 'same object returned');
    LPool.ReleaseObject(LObj2);
  finally
    LPool.Free;
  end;
  WriteLn('PASS: Release and reacquire');
end;

procedure TestPoolExhaustion;
var
  LPool: TTestPool;
  LObj: TTestObject;
  LPtr: Pointer;
  LSuccess: Boolean;
  I: Integer;
begin
  LPool := TTestPool.Create(2,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end);
  try
    for I := 0 to 1 do
    begin
      LSuccess := LPool.AcquireObject(LObj);
      Check(LSuccess, 'acquire ' + IntToStr(I));
    end;
    CheckEqual(Int64(2), Int64(LPool.TotalCreated), 'total created = 2');

    LSuccess := LPool.AcquireObject(LObj);
    Check(not LSuccess, 'pool exhausted');
    Check(not LPool.TryAcquire(LPtr), 'try acquire also fails');
  finally
    LPool.Free;
  end;
  WriteLn('PASS: Pool exhaustion');
end;

procedure TestReset;
var
  LPool: TTestPool;
  LObjs: array[0..2] of TTestObject;
  LSuccess: Boolean;
  LI: Integer;
begin
  LPool := TTestPool.Create(3,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end);
  try
    for LI := 0 to 2 do
    begin
      LSuccess := LPool.AcquireObject(LObjs[LI]);
      Check(LSuccess, 'acquire ' + IntToStr(LI));
    end;
    CheckEqual(Int64(3), Int64(LPool.TotalCreated), 'total created = 3');
    for LI := 0 to 2 do
      LPool.ReleaseObject(LObjs[LI]);
    CheckEqual(Int64(3), Int64(LPool.InPoolCount), 'in-pool = 3 before reset');

    LPool.Reset;
    CheckEqual(Int64(0), Int64(LPool.InPoolCount), 'in-pool after reset');
    CheckEqual(Int64(0), Int64(LPool.TotalCreated), 'total created after reset');

    Check(LPool.AcquireObject(LObjs[0]), 'acquire after reset');
    CheckEqual(Int64(1), Int64(LPool.TotalCreated), 'total created after post-reset acquire');
    LPool.ReleaseObject(LObjs[0]);
  finally
    LPool.Free;
  end;
  WriteLn('PASS: Reset');
end;

procedure TestMultipleAcquireReleaseCycle;
var
  LPool: TTestPool;
  LObjs: array[0..9] of TTestObject;
  LI: Integer;
begin
  LPool := TTestPool.Create(10,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end);
  try
    for LI := 0 to 9 do
      Check(LPool.AcquireObject(LObjs[LI]), 'acquire ' + IntToStr(LI));
    CheckEqual(Int64(10), Int64(LPool.TotalCreated), 'total = 10');
    CheckEqual(Int64(0), Int64(LPool.InPoolCount), 'in-pool = 0');

    for LI := 0 to 9 do
      LPool.ReleaseObject(LObjs[LI]);
    CheckEqual(Int64(10), Int64(LPool.InPoolCount), 'in-pool = 10 after release all');

    for LI := 0 to 9 do
      Check(LPool.AcquireObject(LObjs[LI]), 'reacquire ' + IntToStr(LI));
    CheckEqual(Int64(10), Int64(LPool.TotalCreated), 'total still 10');
    CheckEqual(Int64(0), Int64(LPool.InPoolCount), 'in-pool = 0 after reacquire');

    for LI := 0 to 9 do
      LPool.ReleaseObject(LObjs[LI]);
  finally
    LPool.Free;
  end;
  WriteLn('PASS: Multiple acquire/release cycle');
end;

procedure TestPointerInterface;
var
  LPool: TTestPool;
  LPtr: Pointer;
begin
  LPool := TTestPool.Create(3,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end);
  try
    Check(LPool.Acquire(LPtr), 'pointer acquire');
    Check(LPtr <> nil, 'pointer not nil');
    LPool.Release(LPtr);
    CheckEqual(Int64(1), Int64(LPool.InPoolCount), 'in-pool after pointer release');
  finally
    LPool.Free;
  end;
  WriteLn('PASS: Pointer interface');
end;

procedure TestWithInitCallback;
var
  LPool: TTestPool;
  LObj: TTestObject;
  LInitCalled: Integer;
begin
  LInitCalled := 0;
  LPool := TTestPool.Create(3,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end,
    procedure(AObj: TTestObject)
    begin
      AObj.Value := 42;
      Inc(LInitCalled);
    end);
  try
    Check(LPool.AcquireObject(LObj), 'acquire with init');
    CheckEqual(42, LObj.Value, 'init callback set value');
    CheckEqual(1, LInitCalled, 'init called once');
    LPool.ReleaseObject(LObj);

    Check(LPool.AcquireObject(LObj), 'reacquire with init');
    CheckEqual(42, LObj.Value, 'init called again on reacquire');
    CheckEqual(2, LInitCalled, 'init called twice');
    LPool.ReleaseObject(LObj);
  finally
    LPool.Free;
  end;
  WriteLn('PASS: With init callback');
end;

procedure TestWithFinalizeCallback;
var
  LPool: TTestPool;
  LObj: TTestObject;
  LFinalizeCalled: Integer;
begin
  LFinalizeCalled := 0;
  LPool := TTestPool.Create(3,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end,
    nil,
    procedure(AObj: TTestObject)
    begin
      Inc(LFinalizeCalled);
    end);
  try
    Check(LPool.AcquireObject(LObj), 'acquire');
    LPool.ReleaseObject(LObj);
    CheckEqual(1, LFinalizeCalled, 'finalize called on release');

    Check(LPool.AcquireObject(LObj), 'reacquire');
    LPool.ReleaseObject(LObj);
    CheckEqual(2, LFinalizeCalled, 'finalize called again');
  finally
    LPool.Free;
  end;
  WriteLn('PASS: With finalize callback');
end;

procedure TestTConfigBuilder;
var
  LPool: TTestPool;
  LObj: TTestObject;
begin
  LPool := TTestPool.Create(
    TTestPool.TConfig.Default
      .WithMaxSize(3)
      .WithCreator(
        function: TTestObject
        begin
          Result := TTestObject.Create;
        end)
  );
  try
    CheckEqual(Int64(3), Int64(LPool.MaxObjects), 'config max size');
    Check(LPool.AcquireObject(LObj), 'acquire with config');
    LPool.ReleaseObject(LObj);
  finally
    LPool.Free;
  end;
  WriteLn('PASS: TConfig builder');
end;

{ R-15 regression: MaxSize boundary + TotalCreated counter accuracy }
procedure TestMaxSizeBoundary;
var
  LPool: TTestPool;
  LObj1, LObj2, LDummy: TTestObject;
begin
  LPool := TTestPool.Create(2,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end);
  try
    { Acquire 2 distinct objects (MaxSize=2) }
    Check(LPool.AcquireObject(LObj1), 'acquire 1');
    Check(LPool.AcquireObject(LObj2), 'acquire 2');
    CheckEqual(Int64(2), Int64(LPool.TotalCreated), 'total = 2');

    { Pool exhausted — use LDummy to avoid overwriting LObj1 }
    Check(not LPool.AcquireObject(LDummy), 'pool full at MaxSize');

    { Release both to pool }
    LPool.ReleaseObject(LObj1);
    LPool.ReleaseObject(LObj2);
    CheckEqual(Int64(2), Int64(LPool.InPoolCount), 'pool full');

    { Reacquire — no new creation }
    Check(LPool.AcquireObject(LObj1), 'reacquire 1');
    Check(LPool.AcquireObject(LObj2), 'reacquire 2');
    CheckEqual(Int64(2), Int64(LPool.TotalCreated), 'total still 2');

    { Release both again }
    LPool.ReleaseObject(LObj1);
    LPool.ReleaseObject(LObj2);
    CheckEqual(Int64(2), Int64(LPool.InPoolCount), 'pool full again');

    { Reset clears everything }
    LPool.Reset;
    CheckEqual(Int64(0), Int64(LPool.TotalCreated), 'total = 0 after reset');
    CheckEqual(Int64(0), Int64(LPool.InPoolCount), 'in-pool = 0 after reset');

    { Post-reset: can create new objects }
    Check(LPool.AcquireObject(LObj1), 'post-reset acquire 1');
    Check(LPool.AcquireObject(LObj2), 'post-reset acquire 2');
    CheckEqual(Int64(2), Int64(LPool.TotalCreated), 'total = 2 after post-reset');
    LPool.ReleaseObject(LObj1);
    LPool.ReleaseObject(LObj2);
  finally
    LPool.Free;
  end;
  WriteLn('PASS: MaxSize boundary (R-15)');
end;

{ R-22 regression: double-release detection }
procedure TestDoubleReleaseDetection;
var
  LPool: TTestPool;
  LObj: TTestObject;
  LCaught: Boolean;
begin
  LPool := TTestPool.Create(3,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end);
  try
    Check(LPool.AcquireObject(LObj), 'acquire');
    LPool.ReleaseObject(LObj);

    { Double release should raise EDoubleFree }
    LCaught := False;
    try
      LPool.ReleaseObject(LObj);
    except
      on E: EDoubleFree do
        LCaught := True;
    end;
    Check(LCaught, 'double release must raise EDoubleFree');
  finally
    LPool.Free;
  end;
  WriteLn('PASS: Double release detection');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.pool.object_pool');
  T.Run('Create/Destroy lifecycle', @TestCreateAndDestroy);
  T.Run('Acquire returns valid object', @TestAcquireReturnsValidObject);
  T.Run('Release and reacquire', @TestReleaseAndReacquire);
  T.Run('Pool exhaustion', @TestPoolExhaustion);
  T.Run('Reset', @TestReset);
  T.Run('Multiple acquire/release cycle', @TestMultipleAcquireReleaseCycle);
  T.Run('Pointer interface', @TestPointerInterface);
  T.Run('With init callback', @TestWithInitCallback);
  T.Run('With finalize callback', @TestWithFinalizeCallback);
  T.Run('TConfig builder', @TestTConfigBuilder);
  T.Run('MaxSize boundary (R-15)', @TestMaxSizeBoundary);
  T.Run('Double release detection (R-22)', @TestDoubleReleaseDetection);
  T.Summary;
end.
