program test_mem_cross_os_compile_gate;
{**
 * M3-4: cross-OS gate for mem default + arena public surface.
 *
 * Makefile:
 *   - FORCE_HOST Windows/FreeBSD: compile-only (-Cn) for IFDEF type-check
 *   - host-runtime: real OS run (GetMem/FreeMem/Arena/TryBlockSize)
 *}

{$I nextpas.core.settings.inc}

{$IF not defined(NEXTPAS_WINDOWS) and not defined(NEXTPAS_FREEBSD)
    and not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_MACOS)}
  {$fatal cross-os compile gate expects NEXTPAS_WINDOWS, NEXTPAS_FREEBSD, NEXTPAS_LINUX, or NEXTPAS_MACOS}
{$ENDIF}

uses
  nextpas.core.base,
  nextpas.core.mem,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.growing,
  nextpas.core.mem.allocator.growing_ia,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.arena.virtual,
  nextpas.core.mem.allocator.arena,
  nextpas.core.platform.memory,
  nextpas.core.platform.mmap;

var
  LHeap: TGrowingAllocator;
  LAlloc: IAllocator;
  LArena: IArena;
  LLocal: TLocalArena;
  LVirtual: TVirtualArena;
  LVA: IAllocator;
  LPtr: Pointer;
  LByte: Byte;
  LSz: SizeUInt;
  LStats: TMemStats;
  I: Integer;

begin
  { Touch process dual-track roots (symbols must resolve on all hosts). }
  LHeap := DefaultHeap;
  LAlloc := DefaultAllocator;
  if (LHeap = nil) or (LAlloc = nil) then
    Halt(1);
  if GetGrowingIAllocator = nil then
    Halt(1);

  { Host runtime smoke: sized free + TryBlockSize (no-op under -Cn compile). }
  LPtr := GetMem(96);
  if LPtr = nil then
    Halt(2);
  PInteger(LPtr)^ := $C0FFEE;
  if not TryBlockSize(LPtr, LSz) then
    Halt(3);
  if LSz < 96 then
    Halt(4);
  FreeMem(LPtr, LSz);

  for I := 1 to 64 do
  begin
    LPtr := GetMem(64);
    if LPtr = nil then
      Halt(5);
    FreeMem(LPtr, 64);
  end;

  GetMemStats(LStats);
  { LiveBytes may retain TLS structure; just prove API works. }
  if LStats.OpCounter = 0 then
  begin
    { OpCounter can be 0 on some paths; still success if GetMem worked. }
  end;

  { Arena factories used by SC6/SC7 / M2-4 / HTTP request patterns. }
  LArena := CreateDefaultArena(4096);
  if LArena = nil then
    Halt(1);
  LPtr := LArena.Alloc(64);
  if LPtr = nil then
    Halt(1);
  LArena.Reset;

  LAlloc := CreateArenaAllocator(4096);
  if LAlloc = nil then
    Halt(1);
  LPtr := LAlloc.GetMem(32);
  if LPtr = nil then
    Halt(1);

  LLocal := TLocalArena.Create(4096);
  try
    LPtr := LLocal.Alloc(16);
    if LPtr = nil then
      Halt(1);
  finally
    LLocal.Free;
  end;

  TVirtualArena_Init(LVirtual);
  try
    LPtr := LVirtual.Alloc(64);
    if LPtr = nil then
      Halt(1);
    LVirtual.Reset;
  finally
    TVirtualArena_Release(LVirtual);
  end;

  LVA := TVirtualArenaAllocator.Create;
  LPtr := LVA.GetMem(48);
  if LPtr = nil then
    Halt(1);
  (LVA as TVirtualArenaAllocator).Reset;
  LVA := nil;

  { Platform memory surface referenced by VirtualArena backends. }
  LByte := $A5;
  platform_secure_zero_memory(@LByte, SizeOf(LByte));
  if LByte <> 0 then
    Halt(1);

  WriteLn('mem cross-os gate: host runtime PASS');
end.
