program test_arena_class;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.layout,
  nextpas.core.mem.error,
  nextpas.core.mem.blockpool;

var
  T: TTestRunner;

procedure TestBasicAlloc;
var A: TArena; R: TAllocResult;
begin
  A := TArena.Create(1024);
  try
    R := A.Alloc(TMemLayout.Create(64));
    Check(R.IsOk, 'alloc 64 ok');
    Check(R.Ptr <> nil, 'ptr not nil');
    Check(A.UsedSize >= 64, 'used >= 64');
    Check(A.RemainingSize <= 1024 - 64, 'remaining <= 960');
  finally
    A.Free;
  end;
end;

procedure TestMultipleAllocs;
var A: TArena; R1, R2, R3: TAllocResult;
begin
  A := TArena.Create(256);
  try
    R1 := A.Alloc(TMemLayout.Create(32));
    R2 := A.Alloc(TMemLayout.Create(32));
    R3 := A.Alloc(TMemLayout.Create(32));
    Check(R1.IsOk and R2.IsOk and R3.IsOk, 'all allocs ok');
    Check(R1.Ptr <> R2.Ptr, 'different ptrs 1-2');
    Check(R2.Ptr <> R3.Ptr, 'different ptrs 2-3');
    Check(PtrUInt(R2.Ptr) > PtrUInt(R1.Ptr), 'monotonic');
  finally
    A.Free;
  end;
end;

procedure TestExhaust;
var A: TArena; R: TAllocResult;
begin
  A := TArena.Create(100);
  try
    R := A.Alloc(TMemLayout.Create(80));
    Check(R.IsOk, 'first alloc ok');
    R := A.Alloc(TMemLayout.Create(80));
    Check(not R.IsOk, 'second alloc fails (OOM)');
  finally
    A.Free;
  end;
end;

procedure TestReset;
var A: TArena; R: TAllocResult;
begin
  A := TArena.Create(128);
  try
    A.Alloc(TMemLayout.Create(100));
    Check(A.UsedSize >= 100, 'used after alloc');
    A.Reset;
    Check(A.UsedSize = 0, 'used=0 after reset');
    Check(A.RemainingSize = 128, 'remaining=total after reset');
    R := A.Alloc(TMemLayout.Create(100));
    Check(R.IsOk, 'can alloc after reset');
  finally
    A.Free;
  end;
end;

procedure TestMarkRestore;
var A: TArena; M: TArenaMarker; R: TAllocResult;
begin
  A := TArena.Create(512);
  try
    A.Alloc(TMemLayout.Create(64));
    M := A.SaveMark;
    A.Alloc(TMemLayout.Create(128));
    Check(A.UsedSize >= 192, 'used after 2 allocs');
    A.RestoreToMark(M);
    Check(A.UsedSize <= 64 + 16, 'restored to mark');
    R := A.Alloc(TMemLayout.Create(128));
    Check(R.IsOk, 'can alloc after restore');
  finally
    A.Free;
  end;
end;

procedure TestAllocZeroed;
var A: TArena; R: TAllocResult; P: PByte; I: Integer; AllZero: Boolean;
begin
  A := TArena.Create(256);
  try
    R := A.Alloc(TMemLayout.Create(32));
    if R.IsOk then FillChar(R.Ptr^, 32, $FF);
    A.Reset;
    R := A.AllocZeroed(TMemLayout.Create(32));
    Check(R.IsOk, 'alloc zeroed ok');
    P := R.Ptr;
    AllZero := True;
    for I := 0 to 31 do
      if P[I] <> 0 then begin AllZero := False; Break; end;
    Check(AllZero, 'memory is zeroed');
  finally
    A.Free;
  end;
end;

procedure TestAllocFast;
var A: TArena; P1, P2: Pointer;
begin
  A := TArena.Create(256);
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

procedure TestZeroSizeAlloc;
var A: TArena; R: TAllocResult;
begin
  A := TArena.Create(64);
  try
    R := A.Alloc(TMemLayout.Create(0));
    Check(R.IsOk, 'zero size alloc ok');
    Check(R.Ptr = nil, 'zero size returns nil');
  finally
    A.Free;
  end;
end;

procedure TestStats;
var A: TArena;
begin
  A := TArena.Create(256);
  try
    A.Alloc(TMemLayout.Create(32));
    A.Alloc(TMemLayout.Create(64));
    Check(A.TotalAllocCount = 2, 'total allocs=2');
    Check(A.PeakUsed >= 96, 'peak >= 96');
    A.Reset;
    A.Alloc(TMemLayout.Create(16));
    Check(A.TotalAllocCount = 3, 'total allocs=3 after reset');
    Check(A.PeakUsed >= 96, 'peak unchanged after reset');
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
  T.Run('alloc zeroed', @TestAllocZeroed);
  T.Run('alloc fast', @TestAllocFast);
  T.Run('zero size alloc', @TestZeroSizeAlloc);
  T.Run('statistics', @TestStats);
  T.Summary;
end.
