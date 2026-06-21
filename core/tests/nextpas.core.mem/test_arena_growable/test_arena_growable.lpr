program test_arena_growable;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.arena.growable,
  nextpas.core.mem.arena.types,
  nextpas.core.mem.base;

var
  T: TTestRunner;

{ --- 基本分配测试 --- }

procedure TestBasicAlloc;
var
  LConfig: TGrowableArenaConfig;
  LArena: TGrowableArena;
  LP: Pointer;
begin
  LConfig := TGrowableArenaConfig.Default(1024);
  LArena := TGrowableArena.Create(LConfig);
  try
    LP := LArena.Alloc(64);
    Check(LP <> nil, 'alloc 64 ok');
    Check(LArena.UsedSize >= 64, 'used >= 64');
  finally
    LArena.Free;
  end;
end;

procedure TestMultipleAllocs;
var
  LConfig: TGrowableArenaConfig;
  LArena: TGrowableArena;
  LP1, LP2, LP3: Pointer;
begin
  LConfig := TGrowableArenaConfig.Default(256);
  LArena := TGrowableArena.Create(LConfig);
  try
    LP1 := LArena.Alloc(32);
    LP2 := LArena.Alloc(32);
    LP3 := LArena.Alloc(32);
    Check((LP1 <> nil) and (LP2 <> nil) and (LP3 <> nil), 'all allocs ok');
    Check(LP1 <> LP2, 'different ptrs 1-2');
    Check(LP2 <> LP3, 'different ptrs 2-3');
    Check(PtrUInt(LP2) > PtrUInt(LP1), 'monotonic');
  finally
    LArena.Free;
  end;
end;

{ --- 对齐分配测试 --- }

procedure TestAllocAligned;
var
  LConfig: TGrowableArenaConfig;
  LArena: TGrowableArena;
  LP: Pointer;
begin
  LConfig := TGrowableArenaConfig.Default(512);
  LArena := TGrowableArena.Create(LConfig);
  try
    LP := LArena.AllocAligned(32, 64);
    Check(LP <> nil, 'alloc aligned ok');
    CheckEqual(Int64(0), Int64(PtrUInt(LP) mod 64), 'should be 64-byte aligned');
    LP := LArena.AllocAligned(16, 3);
    Check(LP = nil, 'invalid non-power-of-two alignment should fail');
  finally
    LArena.Free;
  end;
end;

{ --- 清零分配测试 --- }

procedure TestAllocZeroed;
var
  LConfig: TGrowableArenaConfig;
  LArena: TGrowableArena;
  LP: PByte;
  I: Integer;
  AllZero: Boolean;
begin
  LConfig := TGrowableArenaConfig.Default(256);
  LArena := TGrowableArena.Create(LConfig);
  try
    LP := LArena.AllocZeroed(32);
    Check(LP <> nil, 'alloc zeroed ok');
    AllZero := True;
    for I := 0 to 31 do
      if LP[I] <> 0 then begin AllZero := False; Break; end;
    Check(AllZero, 'memory is zeroed');
  finally
    LArena.Free;
  end;
end;

{ --- 段增长测试 --- }

procedure TestGeometricGrowth;
var
  LConfig: TGrowableArenaConfig;
  LArena: TGrowableArena;
  I: Integer;
  LP: Pointer;
begin
  LConfig := TGrowableArenaConfig.Default(64);
  LConfig.GrowthKind := agkGeometric;
  LConfig.GrowthFactor := 2.0;
  LArena := TGrowableArena.Create(LConfig);
  try
    { 分配超过初始大小，触发段增长 }
    for I := 1 to 100 do
    begin
      LP := LArena.Alloc(64);
      Check(LP <> nil, 'alloc ' + IntToStr(I) + ' ok');
    end;
    Check(LArena.UsedSize >= 6400, 'used >= 6400');
  finally
    LArena.Free;
  end;
end;

procedure TestLinearGrowth;
var
  LConfig: TGrowableArenaConfig;
  LArena: TGrowableArena;
  I: Integer;
  LP: Pointer;
begin
  LConfig := TGrowableArenaConfig.Default(64);
  LConfig.GrowthKind := agkLinear;
  LConfig.GrowthStep := 128;
  LArena := TGrowableArena.Create(LConfig);
  try
    { 分配超过初始大小，触发段增长 }
    for I := 1 to 100 do
    begin
      LP := LArena.Alloc(64);
      Check(LP <> nil, 'alloc ' + IntToStr(I) + ' ok');
    end;
    Check(LArena.UsedSize >= 6400, 'used >= 6400');
  finally
    LArena.Free;
  end;
end;

{ --- 标记/恢复测试 --- }

procedure TestMarkRestore;
var
  LConfig: TGrowableArenaConfig;
  LArena: TGrowableArena;
  LMark: TArenaMarker;
  LP: Pointer;
begin
  LConfig := TGrowableArenaConfig.Default(512);
  LArena := TGrowableArena.Create(LConfig);
  try
    LArena.Alloc(64);
    LMark := LArena.SaveMark;
    LArena.Alloc(128);
    Check(LArena.UsedSize >= 192, 'used after 2 allocs');
    LArena.RestoreToMark(LMark);
    Check(LArena.UsedSize <= 64 + 16, 'restored to mark');
    LP := LArena.Alloc(128);
    Check(LP <> nil, 'can alloc after restore');
  finally
    LArena.Free;
  end;
end;

procedure TestMarkAcrossSegments;
var
  LConfig: TGrowableArenaConfig;
  LArena: TGrowableArena;
  LMark: TArenaMarker;
  I: Integer;
  LP: Pointer;
begin
  LConfig := TGrowableArenaConfig.Default(64);
  LConfig.GrowthKind := agkGeometric;
  LConfig.GrowthFactor := 2.0;
  LArena := TGrowableArena.Create(LConfig);
  try
    { 分配一些内存 }
    for I := 1 to 10 do
      LArena.Alloc(32);
    LMark := LArena.SaveMark;
    { 分配更多内存，触发段增长 }
    for I := 1 to 100 do
      LArena.Alloc(32);
    Check(LArena.UsedSize > 320, 'used > 320');
    { 恢复到标记 }
    LArena.RestoreToMark(LMark);
    Check(LArena.UsedSize <= 320 + 16, 'restored to mark');
    { 再次分配 }
    LP := LArena.Alloc(32);
    Check(LP <> nil, 'can alloc after restore');
  finally
    LArena.Free;
  end;
end;

{ --- Reset 测试 --- }

procedure TestReset;
var
  LConfig: TGrowableArenaConfig;
  LArena: TGrowableArena;
  LP: Pointer;
begin
  LConfig := TGrowableArenaConfig.Default(256);
  LArena := TGrowableArena.Create(LConfig);
  try
    LArena.Alloc(100);
    Check(LArena.UsedSize >= 100, 'used after alloc');
    LArena.Reset;
    Check(LArena.UsedSize = 0, 'used=0 after reset');
    LP := LArena.Alloc(100);
    Check(LP <> nil, 'can alloc after reset');
  finally
    LArena.Free;
  end;
end;

procedure TestResetKeepSegments;
var
  LConfig: TGrowableArenaConfig;
  LArena: TGrowableArena;
  LP: Pointer;
begin
  LConfig := TGrowableArenaConfig.Default(64);
  LConfig.KeepSegments := True;
  LArena := TGrowableArena.Create(LConfig);
  try
    { 分配超过初始大小，触发段增长 }
    LArena.Alloc(100);
    LArena.Reset;
    Check(LArena.UsedSize = 0, 'used=0 after reset');
    LP := LArena.Alloc(100);
    Check(LP <> nil, 'can alloc after reset with keep segments');
  finally
    LArena.Free;
  end;
end;

{ --- MaxSize 限制测试 --- }

procedure TestMaxSize;
var
  LConfig: TGrowableArenaConfig;
  LArena: TGrowableArena;
  LP: Pointer;
begin
  LConfig := TGrowableArenaConfig.Default(64);
  LConfig.MaxSize := 128;
  LArena := TGrowableArena.Create(LConfig);
  try
    LP := LArena.Alloc(64);
    Check(LP <> nil, 'first alloc ok');
    LP := LArena.Alloc(64);
    Check(LP = nil, 'second alloc fails (max size reached)');
  finally
    LArena.Free;
  end;
end;

{ --- IArena 接口测试 --- }

procedure TestIArenaInterface;
var
  LConfig: TGrowableArenaConfig;
  LArena: TGrowableArena;
  LP: Pointer;
begin
  LConfig := TGrowableArenaConfig.Default(256);
  LArena := TGrowableArena.Create(LConfig);
  try
    LP := LArena.Alloc(64);
    Check(LP <> nil, 'Alloc ok');
    LP := LArena.AllocAligned(32, 16);
    Check(LP <> nil, 'AllocAligned ok');
    LP := LArena.AllocZeroed(16);
    Check(LP <> nil, 'AllocZeroed ok');
    Check(LArena.TotalSize >= 256, 'TotalSize ok');
    Check(LArena.UsedSize > 0, 'UsedSize ok');
    Check(LArena.RemainingSize < 256, 'RemainingSize ok');
  finally
    LArena.Free;
  end;
end;

{ --- 零大小分配测试 --- }

procedure TestZeroSizeAlloc;
var
  LConfig: TGrowableArenaConfig;
  LArena: TGrowableArena;
  LP: Pointer;
begin
  LConfig := TGrowableArenaConfig.Default(64);
  LArena := TGrowableArena.Create(LConfig);
  try
    LP := LArena.Alloc(0);
    Check(LP = nil, 'zero size returns nil');
  finally
    LArena.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.arena_growable');
  T.Run('basic alloc', @TestBasicAlloc);
  T.Run('multiple allocs', @TestMultipleAllocs);
  T.Run('alloc aligned', @TestAllocAligned);
  T.Run('alloc zeroed', @TestAllocZeroed);
  T.Run('geometric growth', @TestGeometricGrowth);
  T.Run('linear growth', @TestLinearGrowth);
  T.Run('mark/restore', @TestMarkRestore);
  T.Run('mark across segments', @TestMarkAcrossSegments);
  T.Run('reset', @TestReset);
  T.Run('reset keep segments', @TestResetKeepSegments);
  T.Run('max size', @TestMaxSize);
  T.Run('IArena interface', @TestIArenaInterface);
  T.Run('zero size alloc', @TestZeroSizeAlloc);
  T.Summary;
end.
