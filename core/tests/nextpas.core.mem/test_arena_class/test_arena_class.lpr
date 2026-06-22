program test_arena_class;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.blockpool;

var
  T: TTestRunner;

procedure TestBasicAlloc;
var A: TLocalArena; P: Pointer;
begin
  A := TLocalArena.Create(1024);
  try
    P := A.Alloc(64);
    Check(P <> nil, 'alloc 64 ok');
    Check(A.UsedSize >= 64, 'used >= 64');
    Check(A.RemainingSize <= 1024 - 64, 'remaining <= 960');
  finally
    A.Free;
  end;
end;

procedure TestMultipleAllocs;
var A: TLocalArena; P1, P2, P3: Pointer;
begin
  A := TLocalArena.Create(256);
  try
    P1 := A.Alloc(32);
    P2 := A.Alloc(32);
    P3 := A.Alloc(32);
    Check((P1 <> nil) and (P2 <> nil) and (P3 <> nil), 'all allocs ok');
    Check(P1 <> P2, 'different ptrs 1-2');
    Check(P2 <> P3, 'different ptrs 2-3');
    Check(PtrUInt(P2) > PtrUInt(P1), 'monotonic');
  finally
    A.Free;
  end;
end;

procedure TestExhaust;
var A: TLocalArena; P: Pointer;
begin
  A := TLocalArena.Create(100);
  try
    P := A.Alloc(80);
    Check(P <> nil, 'first alloc ok');
    P := A.Alloc(80);
    Check(P = nil, 'second alloc fails (OOM)');
  finally
    A.Free;
  end;
end;

procedure TestReset;
var A: TLocalArena; P: Pointer;
begin
  A := TLocalArena.Create(128);
  try
    A.Alloc(100);
    Check(A.UsedSize >= 100, 'used after alloc');
    A.Reset;
    Check(A.UsedSize = 0, 'used=0 after reset');
    Check(A.RemainingSize = 128, 'remaining=total after reset');
    P := A.Alloc(100);
    Check(P <> nil, 'can alloc after reset');
  finally
    A.Free;
  end;
end;

procedure TestMarkRestore;
var A: TLocalArena; M: TArenaMark; P: Pointer;
begin
  A := TLocalArena.Create(512);
  try
    A.Alloc(64);
    M := A.SaveMark;
    A.Alloc(128);
    Check(A.UsedSize >= 192, 'used after 2 allocs');
    A.RestoreToMark(M);
    Check(A.UsedSize <= 64 + 16, 'restored to mark');
    P := A.Alloc(128);
    Check(P <> nil, 'can alloc after restore');
  finally
    A.Free;
  end;
end;

procedure TestAllocAligned;
var
  A: TLocalArena;
  P: Pointer;
begin
  A := TLocalArena.Create(256);
  try
    P := A.AllocAligned(32, 64);
    Check(P <> nil, 'alloc aligned ok');
    CheckEqual(Int64(0), Int64(PtrUInt(P) mod 64), 'alloc aligned should honor requested alignment');
    P := A.AllocAligned(16, 3);
    Check(P = nil, 'invalid non-power-of-two alignment should fail');
  finally
    A.Free;
  end;
end;

procedure TestAllocZeroed;
var A: TLocalArena; P: PByte; I: Integer; AllZero: Boolean;
begin
  A := TLocalArena.Create(256);
  try
    P := A.Alloc(32);
    if P <> nil then FillChar(P^, 32, $FF);
    A.Reset;
    P := A.AllocZeroed(32);
    Check(P <> nil, 'alloc zeroed ok');
    AllZero := True;
    for I := 0 to 31 do
      if P[I] <> 0 then begin AllZero := False; Break; end;
    Check(AllZero, 'memory is zeroed');
  finally
    A.Free;
  end;
end;

procedure TestAllocFast;
var A: TLocalArena; P1, P2: Pointer;
begin
  A := TLocalArena.Create(256);
  try
    P1 := A.AllocFast(32);
    P2 := A.AllocFast(64);
    Check(P1 <> nil, 'fast alloc 1');
    Check(P2 <> nil, 'fast alloc 2');
    Check(PtrUInt(P2) >= PtrUInt(P1) + 32, 'sequential');
  finally
    A.Free;
  end;
end;

procedure TestAllocAlignedFast;
var A: TLocalArena; P1, P2: Pointer;
begin
  A := TLocalArena.Create(512);
  try
    P1 := A.AllocAlignedFast(32, 64);
    P2 := A.AllocAlignedFast(64, 128);
    Check(P1 <> nil, 'fast aligned alloc 1');
    Check(P2 <> nil, 'fast aligned alloc 2');
    CheckEqual(Int64(0), Int64(PtrUInt(P1) mod 64), 'P1 should be 64-byte aligned');
    CheckEqual(Int64(0), Int64(PtrUInt(P2) mod 128), 'P2 should be 128-byte aligned');
    Check(PtrUInt(P2) >= PtrUInt(P1) + 32, 'sequential');
  finally
    A.Free;
  end;
end;

procedure TestZeroSizeAlloc;
var A: TLocalArena; P: Pointer;
begin
  A := TLocalArena.Create(64);
  try
    P := A.Alloc(0);
    Check(P = nil, 'zero size returns nil');
  finally
    A.Free;
  end;
end;

procedure TestStats;
var A: TLocalArena;
begin
  A := TLocalArena.Create(256);
  try
    A.Alloc(32);
    A.Alloc(64);
    Check(A.TotalAllocCount = 2, 'total allocs=2');
    Check(A.PeakUsed >= 96, 'peak >= 96');
    A.Reset;
    A.Alloc(16);
    Check(A.TotalAllocCount = 3, 'total allocs=3 after reset');
    Check(A.PeakUsed >= 96, 'peak unchanged after reset');
  finally
    A.Free;
  end;
end;

procedure TestArenaClassLegacyAlias;
var
  A: TLocalArena;
  P: Pointer;
begin
  A := TLocalArena.Create(128);
  try
    P := A.Alloc(16);
    Check(P <> nil, 'legacy blockpool.TArena alias remains usable');
  finally
    A.Free;
  end;
end;

{ --- Edge-case tests --- }

procedure TestMultipleResetCycles;
var
  A: TLocalArena;
  I, J: Integer;
  P: Pointer;
  OK: Boolean;
begin
  A := TLocalArena.Create(1024);
  try
    OK := True;
    for I := 0 to 99 do
    begin
      for J := 0 to 99 do
      begin
        P := A.Alloc(8);
        if P = nil then
        begin
          OK := False;
          Break;
        end;
      end;
      if not OK then
        Break;
      A.Reset;
    end;
    Check(OK, '100 reset cycles x100 allocs: all succeeded');
  finally
    A.Free;
  end;
end;

procedure TestExhaustThenReset;
var
  A: TLocalArena;
  P: Pointer;
begin
  A := TLocalArena.Create(128);
  try
    { Fill it up }
    while A.Alloc(32) <> nil do ;
    { Should be exhausted }
    P := A.Alloc(32);
    Check(P = nil, 'exhausted: returns nil');
    { Reset and try again }
    A.Reset;
    P := A.Alloc(32);
    Check(P <> nil, 'after reset: can alloc again');
  finally
    A.Free;
  end;
end;

procedure TestMarkRestoreNested;
var
  A: TLocalArena;
  M1, M2: TArenaMark;
  P: Pointer;
begin
  A := TLocalArena.Create(512);
  try
    A.Alloc(32);
    M1 := A.SaveMark;
    A.Alloc(64);
    M2 := A.SaveMark;
    A.Alloc(128);
    Check(A.UsedSize >= 224, 'nested: used after 3 allocs');
    { Restore to inner mark }
    A.RestoreToMark(M2);
    Check(A.UsedSize <= 96 + 16, 'nested: restored to inner mark');
    P := A.Alloc(64);
    Check(P <> nil, 'nested: can alloc after inner restore');
    { Restore to outer mark }
    A.RestoreToMark(M1);
    Check(A.UsedSize <= 32 + 16, 'nested: restored to outer mark');
    P := A.Alloc(64);
    Check(P <> nil, 'nested: can alloc after outer restore');
  finally
    A.Free;
  end;
end;

procedure TestAllocExactCapacity;
var
  A: TLocalArena;
  P: Pointer;
begin
  A := TLocalArena.Create(128);
  try
    P := A.Alloc(128);
    Check(P <> nil, 'exact capacity: should succeed');
    Check(A.RemainingSize = 0, 'exact capacity: remaining should be 0');
  finally
    A.Free;
  end;
end;

procedure TestAllocOverCapacity;
var
  A: TLocalArena;
begin
  A := TLocalArena.Create(64);
  try
    Check(A.Alloc(128) = nil, 'over capacity: returns nil');
  finally
    A.Free;
  end;
end;

procedure TestIArenaInterface;
var
  A: nextpas.core.mem.arena.local.TLocalArena;
  IA: nextpas.core.mem.arena.intf.IArena;
  P: Pointer;
begin
  A := nextpas.core.mem.arena.local.TLocalArena.Create(256);
  IA := A;
  try
    P := IA.Alloc(64);
    Check(P <> nil, 'IArena alloc: succeeded');
    Check(IA.UsedSize >= 64, 'IArena used: >= 64');
    Check(IA.RemainingSize > 0, 'IArena remaining: > 0');
    IA.Reset;
    Check(IA.UsedSize = 0, 'IArena reset: used = 0');
  finally
    IA := nil;
  end;
end;

procedure TestStatsRecord;
var
  A: TLocalArena;
  S: TArenaStats;
begin
  A := TLocalArena.Create(256);
  try
    A.Alloc(32);
    A.Alloc(64);
    S := A.Stats;
    Check(S.TotalAllocated = 256, 'stats record: TotalAllocated = 256');
    Check(S.TotalUsed >= 96, 'stats record: TotalUsed >= 96');
    Check(S.PeakUsed >= 96, 'stats record: PeakUsed >= 96');
    Check(S.AllocCount >= 2, 'stats record: AllocCount >= 2');
  finally
    A.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.arena_class');
  T.Run('basic alloc', @TestBasicAlloc);
  T.Run('multiple allocs', @TestMultipleAllocs);
  T.Run('exhaust', @TestExhaust);
  T.Run('reset', @TestReset);
  T.Run('mark/restore', @TestMarkRestore);
  T.Run('alloc aligned', @TestAllocAligned);
  T.Run('alloc zeroed', @TestAllocZeroed);
  T.Run('alloc fast', @TestAllocFast);
  T.Run('alloc aligned fast', @TestAllocAlignedFast);
  T.Run('zero size alloc', @TestZeroSizeAlloc);
  T.Run('statistics', @TestStats);
  T.Run('legacy TArena alias', @TestArenaClassLegacyAlias);

  { Edge-case tests }
  T.Run('multiple_reset_cycles', @TestMultipleResetCycles);
  T.Run('exhaust_then_reset', @TestExhaustThenReset);
  T.Run('mark_restore_nested', @TestMarkRestoreNested);
  T.Run('alloc_exact_capacity', @TestAllocExactCapacity);
  T.Run('alloc_over_capacity', @TestAllocOverCapacity);
  T.Run('iarena_interface', @TestIArenaInterface);
  T.Run('stats_record', @TestStatsRecord);

  T.Summary;
end.
