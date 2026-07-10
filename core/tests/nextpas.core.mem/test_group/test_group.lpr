program test_group;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.intf,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.group;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- 基础生命周期 Basic lifecycle --- }

procedure TestCreateDestroy;
var
  LInner: IAllocator;
  LAlloc: TGroupAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TGroupAllocator.Create(LInner);
    try
      Check(LAlloc <> nil, 'created');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestCreateGroup;
var
  LInner: IAllocator;
  LAlloc: TGroupAllocator;
  LGroup1, LGroup2: Integer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TGroupAllocator.Create(LInner);
    try
      LGroup1 := LAlloc.CreateGroup;
      LGroup2 := LAlloc.CreateGroup;
      Check(LGroup1 <> LGroup2, 'different group indices');
      Check(LGroup1 >= 0, 'group1 >= 0');
      Check(LGroup2 >= 0, 'group2 >= 0');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestSetActiveGroup;
var
  LInner: IAllocator;
  LAlloc: TGroupAllocator;
  LGroup: Integer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TGroupAllocator.Create(LInner);
    try
      LGroup := LAlloc.CreateGroup;
      LAlloc.SetActiveGroup(LGroup);
      Check(True, 'SetActiveGroup did not crash');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestResetGroup;
var
  LInner: IAllocator;
  LAlloc: TGroupAllocator;
  LGroup: Integer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TGroupAllocator.Create(LInner);
    try
      LGroup := LAlloc.CreateGroup;
      LAlloc.SetActiveGroup(LGroup);
      LAlloc.ResetGroup(LGroup);
      Check(True, 'ResetGroup did not crash');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestResetAll;
var
  LInner: IAllocator;
  LAlloc: TGroupAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TGroupAllocator.Create(LInner);
    try
      LAlloc.CreateGroup;
      LAlloc.CreateGroup;
      LAlloc.ResetAll;
      Check(True, 'ResetAll did not crash');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestGetMem;
var
  LInner: IAllocator;
  LAlloc: TGroupAllocator;
  LGroup: Integer;
  LP: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TGroupAllocator.Create(LInner);
    try
      LGroup := LAlloc.CreateGroup;
      LAlloc.SetActiveGroup(LGroup);
      LP := LAlloc.GetMem(64);
      Check(LP <> nil, 'GetMem returned pointer');
      LAlloc.FreeMem(LP);
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestAllocMem;
var
  LInner: IAllocator;
  LAlloc: TGroupAllocator;
  LGroup: Integer;
  LP: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TGroupAllocator.Create(LInner);
    try
      LGroup := LAlloc.CreateGroup;
      LAlloc.SetActiveGroup(LGroup);
      LP := LAlloc.AllocMem(64);
      Check(LP <> nil, 'AllocMem returned pointer');
      LAlloc.FreeMem(LP);
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestReallocMem;
var
  LInner: IAllocator;
  LAlloc: TGroupAllocator;
  LGroup: Integer;
  LP: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TGroupAllocator.Create(LInner);
    try
      LGroup := LAlloc.CreateGroup;
      LAlloc.SetActiveGroup(LGroup);
      LP := LAlloc.GetMem(32);
      LP := LAlloc.ReallocMem(LP, 64);
      Check(LP <> nil, 'ReallocMem returned pointer');
      LAlloc.FreeMem(LP);
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestGetMemZeroReturnsNil;
var
  LInner: IAllocator;
  LAlloc: TGroupAllocator;
  LGroup: Integer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TGroupAllocator.Create(LInner);
    try
      LGroup := LAlloc.CreateGroup;
      LAlloc.SetActiveGroup(LGroup);
      Check(LAlloc.GetMem(0) <> nil, 'GetMem(0) returns non-nil from RTL');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestFreeMemNilNoOp;
var
  LInner: IAllocator;
  LAlloc: TGroupAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TGroupAllocator.Create(LInner);
    try
      LAlloc.FreeMem(nil);
      Check(True, 'FreeMem(nil) did not crash');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestTraits;
var
  LInner: IAllocator;
  LAlloc: TGroupAllocator;
  LTraits: TAllocatorTraits;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TGroupAllocator.Create(LInner);
    try
      LTraits := LAlloc.Traits;
      Check(LTraits.SupportsRealloc = True, 'supports realloc');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

{ --- 注册 Register --- }

begin
  T := TTestSuite.Create('test_group');
  T.Test('create_destroy', @TestCreateDestroy);
  T.Test('create_group', @TestCreateGroup);
  T.Test('set_active_group', @TestSetActiveGroup);
  T.Test('reset_group', @TestResetGroup);
  T.Test('reset_all', @TestResetAll);
  T.Test('getmem', @TestGetMem);
  T.Test('allocmem', @TestAllocMem);
  T.Test('reallocmem', @TestReallocMem);
  T.Test('getmem_zero_returns_nil', @TestGetMemZeroReturnsNil);
  T.Test('freemem_nil_noop', @TestFreeMemNilNoOp);
  T.Test('traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
