program test_object_pool;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.testing,
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
    CheckEqual(Int64(0), Int64(LPool.InPoolCount), 'initial in-pool count');
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
  LPool := TTestPool.Create(5,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end);
  try
    Check(LPool.AcquireObject(LObj), 'AcquireObject should succeed');
    Check(LObj <> nil, 'acquired object should not be nil');
    CheckEqual(Int64(1), Int64(LPool.TotalCreated), 'total created after acquire');
    CheckEqual(Int64(0), Int64(LPool.InPoolCount), 'in-pool after acquire');
    LPool.ReleaseObject(LObj);
  finally
    LPool.Free;
  end;
  WriteLn('PASS: Acquire returns valid object');
end;

procedure TestReleaseAndReacquire;
var
  LPool: TTestPool;
  LObj1, LObj2: TTestObject;
begin
  LPool := TTestPool.Create(5,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end);
  try
    LPool.AcquireObject(LObj1);
    LObj1.Value := 42;
    LPool.ReleaseObject(LObj1);
    CheckEqual(Int64(1), Int64(LPool.InPoolCount), 'in-pool after release');

    LPool.AcquireObject(LObj2);
    Check(LObj1 = LObj2, 'released object should be re-acquired');
    CheckEqual(Int64(1), Int64(LPool.TotalCreated), 'should not create new object');
    CheckEqual(Int64(0), Int64(LPool.InPoolCount), 'in-pool after re-acquire');
    LPool.ReleaseObject(LObj2);
  finally
    LPool.Free;
  end;
  WriteLn('PASS: Release and reacquire');
end;

procedure TestPoolExhaustion;
var
  LPool: TTestPool;
  LObj1, LObj2, LObj3: TTestObject;
  LSuccess: Boolean;
begin
  LPool := TTestPool.Create(2,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end);
  try
    LSuccess := LPool.AcquireObject(LObj1);
    Check(LSuccess, 'first acquire');
    LSuccess := LPool.AcquireObject(LObj2);
    Check(LSuccess, 'second acquire');
    CheckEqual(Int64(2), Int64(LPool.TotalCreated), 'total created = 2');

    // Pool capacity reached
    LSuccess := LPool.AcquireObject(LObj3);
    Check(not LSuccess, 'third acquire should fail (capacity exhausted)');

    LPool.ReleaseObject(LObj1);
    LPool.ReleaseObject(LObj2);
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
    // Acquire 3 objects and release them
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

    // Should be able to create new objects after reset
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
    // Acquire all
    for LI := 0 to 9 do
    begin
      Check(LPool.AcquireObject(LObjs[LI]), 'acquire ' + IntToStr(LI));
      LObjs[LI].Value := LI;
    end;
    CheckEqual(Int64(10), Int64(LPool.TotalCreated), 'total created = 10');
    CheckEqual(Int64(0), Int64(LPool.InPoolCount), 'in-pool = 0');

    // Release all
    for LI := 0 to 9 do
      LPool.ReleaseObject(LObjs[LI]);
    CheckEqual(Int64(10), Int64(LPool.InPoolCount), 'in-pool = 10 after release all');

    // Re-acquire all (should reuse, not create new)
    for LI := 0 to 9 do
      Check(LPool.AcquireObject(LObjs[LI]), 're-acquire ' + IntToStr(LI));
    CheckEqual(Int64(10), Int64(LPool.TotalCreated), 'total created still 10');
    CheckEqual(Int64(0), Int64(LPool.InPoolCount), 'in-pool = 0 after re-acquire');

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
  LPool := TTestPool.Create(5,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end);
  try
    Check(LPool.Acquire(LPtr), 'pointer Acquire');
    Check(LPtr <> nil, 'pointer not nil');
    LPool.Release(LPtr);
    CheckEqual(Int64(1), Int64(LPool.InPoolCount), 'in-pool after pointer release');
  finally
    LPool.Free;
  end;
  WriteLn('PASS: Pointer interface (Acquire/Release)');
end;

procedure TestWithInitCallback;
var
  LPool: TTestPool;
  LObj: TTestObject;
begin
  LPool := TTestPool.Create(5,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end,
    procedure(Obj: TTestObject)
    begin
      Obj.Value := 100;
    end);
  try
    LPool.AcquireObject(LObj);
    CheckEqual(Int64(100), Int64(LObj.Value), 'init callback should set value');
    LPool.ReleaseObject(LObj);

    // Re-acquire: init should be called again
    LPool.AcquireObject(LObj);
    CheckEqual(Int64(100), Int64(LObj.Value), 'init callback on re-acquire');
    LPool.ReleaseObject(LObj);
  finally
    LPool.Free;
  end;
  WriteLn('PASS: With init callback');
end;

procedure TestWithFinalizeCallback;
var
  LFinalized: Boolean;
  LPool: TTestPool;
  LObj: TTestObject;
begin
  LFinalized := False;
  LPool := TTestPool.Create(5,
    function: TTestObject
    begin
      Result := TTestObject.Create;
    end,
    nil,
    procedure(Obj: TTestObject)
    begin
      LFinalized := True;
    end);
  try
    LPool.AcquireObject(LObj);
    Check(not LFinalized, 'not yet finalized');
    LPool.ReleaseObject(LObj);
    Check(LFinalized, 'should be finalized on release');
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
  T.Summary;
end.
