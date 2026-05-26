program test_arena;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.arena,
  nextpas.core.mem.base;

var
  T: TTestRunner;

procedure TestArenaInit;
var
  LA: TArena;
begin
  LA.Init(1024);
  CheckEqual(Int64(1024), Int64(LA.Capacity), 'capacity');
  CheckEqual(Int64(0), Int64(LA.BytesUsed), 'bytes used');
  CheckEqual(Int64(1024), Int64(LA.BytesRemaining), 'bytes remaining');
  LA.Done;
end;

procedure TestArenaAlloc;
var
  LA: TArena;
  LP1, LP2: Pointer;
begin
  LA.Init(256);
  LP1 := LA.Alloc(64);
  Check(LP1 <> nil, 'first alloc');
  CheckEqual(Int64(64), Int64(LA.BytesUsed));

  LP2 := LA.Alloc(64);
  Check(LP2 <> nil, 'second alloc');
  Check(LP2 <> LP1, 'different pointers');
  CheckEqual(Int64(128), Int64(LA.BytesUsed));
  LA.Done;
end;

procedure TestArenaAllocExhaust;
var
  LA: TArena;
  LP: Pointer;
begin
  LA.Init(100);
  LP := LA.Alloc(100);
  Check(LP <> nil, 'exact fit');
  LP := LA.Alloc(1);
  Check(LP = nil, 'should return nil when exhausted');
  LA.Done;
end;

procedure TestArenaAllocAligned;
var
  LA: TArena;
  LP: Pointer;
begin
  LA.Init(1024);
  LA.Alloc(1);
  LP := LA.AllocAligned(64, 16);
  Check(LP <> nil, 'aligned alloc');
  Check(SizeUInt(LP) mod 16 = 0, 'should be 16-byte aligned');

  LP := LA.AllocAligned(32, 64);
  Check(LP <> nil, 'aligned alloc 64');
  Check(SizeUInt(LP) mod 64 = 0, 'should be 64-byte aligned');
  LA.Done;
end;

procedure TestArenaReset;
var
  LA: TArena;
begin
  LA.Init(256);
  LA.Alloc(100);
  LA.Alloc(50);
  CheckEqual(Int64(150), Int64(LA.BytesUsed));

  LA.Reset;
  CheckEqual(Int64(0), Int64(LA.BytesUsed), 'reset clears');
  CheckEqual(Int64(256), Int64(LA.BytesRemaining));

  Check(LA.Alloc(256) <> nil, 'can reuse after reset');
  LA.Done;
end;

procedure TestArenaMark;
var
  LA: TArena;
  LMark: TArenaMarker;
  LP: Pointer;
begin
  LA.Init(256);
  LA.Alloc(32);
  LMark := LA.Mark;
  CheckEqual(Int64(32), Int64(LMark));

  LA.Alloc(64);
  CheckEqual(Int64(96), Int64(LA.BytesUsed));

  LA.Restore(LMark);
  CheckEqual(Int64(32), Int64(LA.BytesUsed), 'restored to mark');

  LP := LA.Alloc(64);
  Check(LP <> nil, 'can alloc after restore');
  LA.Done;
end;

procedure TestArenaMarkNested;
var
  LA: TArena;
  LMark1, LMark2: TArenaMarker;
begin
  LA.Init(256);
  LA.Alloc(10);
  LMark1 := LA.Mark;

  LA.Alloc(20);
  LMark2 := LA.Mark;

  LA.Alloc(30);
  CheckEqual(Int64(60), Int64(LA.BytesUsed));

  LA.Restore(LMark2);
  CheckEqual(Int64(30), Int64(LA.BytesUsed));

  LA.Restore(LMark1);
  CheckEqual(Int64(10), Int64(LA.BytesUsed));
  LA.Done;
end;

procedure TestArenaWriteRead;
var
  LA: TArena;
  LP: PInteger;
begin
  LA.Init(256);
  LP := PInteger(LA.Alloc(SizeOf(Integer)));
  Check(LP <> nil);
  LP^ := 12345;
  Check(LP^ = 12345, 'write/read through arena pointer');
  LA.Done;
end;

procedure TestArenaDone;
var
  LA: TArena;
begin
  LA.Init(1024);
  LA.Alloc(512);
  LA.Done;
  CheckEqual(Int64(0), Int64(LA.BytesUsed), 'done clears state');
  CheckEqual(Int64(0), Int64(LA.Capacity), 'done clears capacity');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.arena');
  T.Run('Init', @TestArenaInit);
  T.Run('Alloc', @TestArenaAlloc);
  T.Run('Alloc exhaust', @TestArenaAllocExhaust);
  T.Run('AllocAligned', @TestArenaAllocAligned);
  T.Run('Reset', @TestArenaReset);
  T.Run('Mark/Restore', @TestArenaMark);
  T.Run('Mark nested', @TestArenaMarkNested);
  T.Run('Write/Read', @TestArenaWriteRead);
  T.Run('Done', @TestArenaDone);
  T.Summary;
end.
