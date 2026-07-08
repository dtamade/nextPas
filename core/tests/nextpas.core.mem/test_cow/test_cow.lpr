program test_cow;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.cow,
  nextpas.core.mem.error;

var
  T: TTestSuite;

procedure TestCreateAndDestroy;
var
  LCow: TCowAllocator;
begin
  LCow := TCowAllocator.Create(DefaultAllocator);
  try
    Check(LCow <> nil, 'cow should be created');
  finally
    LCow.Free;
  end;
end;

procedure TestBasicAlloc;
var
  LCow: TCowAllocator;
  LPtr: Pointer;
  LI: Integer;
begin
  LCow := TCowAllocator.Create(DefaultAllocator);
  try
    LPtr := LCow.GetMem(64);
    Check(LPtr <> nil, 'alloc should succeed');

    for LI := 0 to 63 do
      PByte(PtrUInt(LPtr) + PtrUInt(LI))^ := Byte(LI and $FF);

    for LI := 0 to 63 do
      Check(PByte(PtrUInt(LPtr) + PtrUInt(LI))^ = Byte(LI and $FF), 'data should match');

    LCow.FreeMem(LPtr);
  finally
    LCow.Free;
  end;
end;

procedure TestShare;
var
  LCow: TCowAllocator;
  LPtr1, LPtr2: Pointer;
  LI: Integer;
begin
  LCow := TCowAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LCow.GetMem(64);
    Check(LPtr1 <> nil, 'alloc should succeed');

    for LI := 0 to 63 do
      PByte(PtrUInt(LPtr1) + PtrUInt(LI))^ := Byte(LI and $FF);

    { Share creates a reference that shares the same data }
    LPtr2 := LCow.Share(LPtr1);
    Check(LPtr2 <> nil, 'share should succeed');

    { Shared data should be identical }
    for LI := 0 to 63 do
      Check(PByte(PtrUInt(LPtr2) + PtrUInt(LI))^ = Byte(LI and $FF), 'shared data should match');

    { Both should be marked as shared }
    Check(LCow.IsShared(LPtr1), 'original should be shared');
    Check(LCow.IsShared(LPtr2), 'shared ref should be shared');

    LCow.FreeMem(LPtr1);
    LCow.FreeMem(LPtr2);
  finally
    LCow.Free;
  end;
end;

procedure TestWriteNotify;
var
  LCow: TCowAllocator;
  LPtr1, LPtr2, LWritable: Pointer;
  LI: Integer;
begin
  LCow := TCowAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LCow.GetMem(64);
    for LI := 0 to 63 do
      PByte(PtrUInt(LPtr1) + PtrUInt(LI))^ := Byte(LI and $FF);

    LPtr2 := LCow.Share(LPtr1);

    { WriteNotify should give us a writable copy }
    LWritable := LCow.WriteNotify(LPtr2);
    Check(LWritable <> nil, 'WriteNotify should succeed');

    { Modify shared copy }
    PByte(LWritable)^ := $AA;

    { Original should be unchanged }
    Check(PByte(LPtr1)^ = 0, 'original should be unchanged');

    LCow.FreeMem(LPtr1);
    LCow.FreeMem(LPtr2);
  finally
    LCow.Free;
  end;
end;

procedure TestStats;
var
  LCow: TCowAllocator;
  LStats: TCowStats;
  LPtr1, LPtr2: Pointer;
begin
  LCow := TCowAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LCow.GetMem(64);
    LPtr2 := LCow.Share(LPtr1);

    LStats := LCow.GetStats;
    Check(LStats.TotalAllocs = 1, 'total allocs should be 1');
    Check(LStats.SharedAllocs = 1, 'shared allocs should be 1');
    Check(LStats.ActiveRefs = 2, 'active refs should be 2');

    LCow.FreeMem(LPtr1);
    LCow.FreeMem(LPtr2);
  finally
    LCow.Free;
  end;
end;

procedure TestIsShared;
var
  LCow: TCowAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LCow := TCowAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LCow.GetMem(64);
    Check(not LCow.IsShared(LPtr1), 'should not be shared initially');

    LPtr2 := LCow.Share(LPtr1);
    Check(LCow.IsShared(LPtr1), 'should be shared after share');

    LCow.FreeMem(LPtr1);
    LCow.FreeMem(LPtr2);
  finally
    LCow.Free;
  end;
end;

procedure TestNilInner;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TCowAllocator.Create(nil).Free;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'nil inner should raise');
end;

begin
  T := TTestSuite.Create('test_cow');
  T.Test('create_and_destroy', @TestCreateAndDestroy);
  T.Test('basic_alloc', @TestBasicAlloc);
  T.Test('share', @TestShare);
  T.Test('write_notify', @TestWriteNotify);
  T.Test('stats', @TestStats);
  T.Test('is_shared', @TestIsShared);
  T.Test('nil_inner', @TestNilInner);
  T.Run;
  T.Summary;
end.
