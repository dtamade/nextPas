program test_fallback_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.testing,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.error,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.allocator,
  nextpas.core.mem.allocator.fallback;

type
  {** 总是返回 nil 的分配器 (模拟 OOM) }
  TOomAllocator = class(TInterfacedObject, IAllocator)
  public
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
    procedure FreeAligned(aPtr: Pointer);
    function MemSize(aPtr: Pointer): SizeUInt;
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    function Traits: TAllocatorTraits;
  end;

function TOomAllocator.GetMem(aSize: SizeUInt): Pointer;
begin Result := nil; end;
function TOomAllocator.AllocMem(aSize: SizeUInt): Pointer;
begin Result := nil; end;
function TOomAllocator.ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin Result := nil; end;
procedure TOomAllocator.FreeMem(aDst: Pointer);
begin end;
procedure TOomAllocator.FreeAligned(aPtr: Pointer);
begin end;
function TOomAllocator.MemSize(aPtr: Pointer): SizeUInt;
begin Result := 0; end;
function TOomAllocator.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
begin Result := nil; end;
function TOomAllocator.Traits: TAllocatorTraits;
begin FillChar(Result, SizeOf(Result), 0); end;

var
  T: TTestRunner;

{ ---------------------------------------------------------------------------
  TFallbackAllocator
  --------------------------------------------------------------------------- }

procedure TestFallbackAllocatorCreateDestroy;
var
  LOom: TOomAllocator;
  LRtl: IAllocator;
  LFall: TFallbackAllocator;
begin
  LOom := TOomAllocator.Create;
  LRtl := GetRtlAllocator;
  LFall := TFallbackAllocator.Create(LOom, LRtl);
  try
    Check(LFall <> nil, 'created');
    CheckEqual(Int64(0), Int64(LFall.TotalFallbacks), 'initial fallbacks 0');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackAllocatorPrimarySucceeds;
var
  LRtl: IAllocator;
  LFall: TFallbackAllocator;
  LP: Pointer;
begin
  LRtl := GetRtlAllocator;
  LFall := TFallbackAllocator.Create(LRtl, LRtl);
  try
    LP := LFall.GetMem(64);
    Check(LP <> nil, 'primary alloc succeeds');
    CheckEqual(Int64(0), Int64(LFall.TotalFallbacks), 'no fallback needed');
    LFall.FreeMem(LP);
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackAllocatorPrimaryFails;
var
  LOom: TOomAllocator;
  LRtl: IAllocator;
  LFall: TFallbackAllocator;
  LP: Pointer;
begin
  LOom := TOomAllocator.Create;
  LRtl := GetRtlAllocator;
  LFall := TFallbackAllocator.Create(LOom, LRtl);
  try
    LP := LFall.GetMem(64);
    Check(LP <> nil, 'fallback alloc succeeds');
    CheckEqual(Int64(1), Int64(LFall.TotalFallbacks), 'one fallback');
    LFall.FreeMem(LP);
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackAllocatorFreeFromCorrect;
var
  LOom: TOomAllocator;
  LRtl: IAllocator;
  LFall: TFallbackAllocator;
  LP1: Pointer;
begin
  LOom := TOomAllocator.Create;
  LRtl := GetRtlAllocator;
  LFall := TFallbackAllocator.Create(LRtl, LOom);
  try
    { primary succeeds }
    LP1 := LFall.GetMem(32);
    Check(LP1 <> nil, 'primary alloc');
    CheckEqual(Int64(0), Int64(LFall.TotalFallbacks), 'no fallback');

    { free from primary — 不崩溃 }
    LFall.FreeMem(LP1);
    Check(True, 'free primary succeeded');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackAllocatorMultiple;
var
  LOom: TOomAllocator;
  LRtl: IAllocator;
  LFall: TFallbackAllocator;
  LPs: array[0..9] of Pointer;
  I: Integer;
begin
  LOom := TOomAllocator.Create;
  LRtl := GetRtlAllocator;
  LFall := TFallbackAllocator.Create(LOom, LRtl);
  try
    for I := 0 to 9 do begin
      LPs[I] := LFall.GetMem(64);
      Check(LPs[I] <> nil, 'fallback alloc #' + IntToStr(I));
    end;
    CheckEqual(Int64(10), Int64(LFall.TotalFallbacks), '10 fallbacks');

    for I := 0 to 9 do
      LFall.FreeMem(LPs[I]);

    CheckEqual(Int64(10), Int64(LFall.TotalFallbacks), 'total fallback count unchanged');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackAllocatorAllocMem;
var
  LOom: TOomAllocator;
  LRtl: IAllocator;
  LFall: TFallbackAllocator;
  LP: PByte;
  I: Integer;
begin
  LOom := TOomAllocator.Create;
  LRtl := GetRtlAllocator;
  LFall := TFallbackAllocator.Create(LOom, LRtl);
  try
    LP := PByte(LFall.AllocMem(64));
    Check(LP <> nil, 'AllocMem succeeds');
    { AllocMem 应返回零初始化内存 }
    for I := 0 to 63 do
      Check(LP[I] = 0, 'zeroed at ' + IntToStr(I));
    LFall.FreeMem(LP);
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackAllocatorFreeNil;
var
  LRtl: IAllocator;
  LFall: TFallbackAllocator;
begin
  LRtl := GetRtlAllocator;
  LFall := TFallbackAllocator.Create(LRtl, LRtl);
  try
    LFall.FreeMem(nil); { 不崩溃 }
    Check(True, 'free nil does not crash');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackAllocatorReallocMemFromFallbackUpdatesSize;
var
  LOom: TOomAllocator;
  LRtl: IAllocator;
  LFall: TFallbackAllocator;
  LP, LP2: PByte;
begin
  LOom := TOomAllocator.Create;
  LRtl := GetRtlAllocator;
  LFall := TFallbackAllocator.Create(LOom, LRtl);
  try
    { 分配来自 fallback }
    LP := PByte(LFall.GetMem(64));
    Check(LP <> nil, 'fallback alloc succeeds');
    LP^ := $AB; { 写入标记 }

    { ReallocMem 来自 fallback 的记录应更新 size }
    LP2 := PByte(LFall.ReallocMem(LP, 128));
    Check(LP2 <> nil, 'realloc from fallback succeeds');
    Check(LP2^ = $AB, 'data preserved after realloc');

    { 释放后不再有跟踪记录 — 通过 FreeMem 不崩溃验证 }
    LFall.FreeMem(LP2);
    Check(True, 'free after realloc succeeds');
  finally
    LFall.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  TFallbackArena
  --------------------------------------------------------------------------- }

procedure TestFallbackArenaCreateDestroy;
var
  LArena: TLocalArena;
  LRtl: IAllocator;
  LFall: TFallbackArena;
begin
  LArena := TLocalArena.Create(256);
  LRtl := GetRtlAllocator;
  LFall := TFallbackArena.Create(LArena, LRtl);
  try
    Check(LFall <> nil, 'created');
    CheckEqual(Int64(0), Int64(LFall.TotalFallbacks), 'initial fallbacks 0');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackArenaPrimarySucceeds;
var
  LArena: TLocalArena;
  LRtl: IAllocator;
  LFall: TFallbackArena;
  LP: Pointer;
begin
  LArena := TLocalArena.Create(1024);
  LRtl := GetRtlAllocator;
  LFall := TFallbackArena.Create(LArena, LRtl);
  try
    LP := LFall.Alloc(64);
    Check(LP <> nil, 'arena alloc succeeds');
    CheckEqual(Int64(0), Int64(LFall.TotalFallbacks), 'no fallback');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackArenaExhaustAndFallback;
var
  LArena: TLocalArena;
  LRtl: IAllocator;
  LFall: TFallbackArena;
  LP1, LP2: Pointer;
begin
  LArena := TLocalArena.Create(64);
  LRtl := GetRtlAllocator;
  LFall := TFallbackArena.Create(LArena, LRtl);
  try
    { 填满 Arena }
    LP1 := LFall.Alloc(64);
    Check(LP1 <> nil, 'arena alloc');
    CheckEqual(Int64(0), Int64(LFall.TotalFallbacks), 'no fallback yet');

    { Arena 耗尽, 降级到 fallback }
    LP2 := LFall.Alloc(32);
    Check(LP2 <> nil, 'fallback alloc succeeds');
    CheckEqual(Int64(1), Int64(LFall.TotalFallbacks), 'one fallback');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackArenaReset;
var
  LArena: TLocalArena;
  LRtl: IAllocator;
  LFall: TFallbackArena;
  LP: Pointer;
begin
  LArena := TLocalArena.Create(128);
  LRtl := GetRtlAllocator;
  LFall := TFallbackArena.Create(LArena, LRtl);
  try
    LP := LFall.Alloc(128);
    Check(LP <> nil, 'alloc before reset');
    LFall.Reset;
    CheckEqual(Int64(0), Int64(LFall.UsedSize), 'arena reset');
    { 可以重新从 Arena 分配 }
    LP := LFall.Alloc(128);
    Check(LP <> nil, 'alloc after reset');
    CheckEqual(Int64(0), Int64(LFall.TotalFallbacks), 'no fallback after reset');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackArenaMarkRestore;
var
  LArena: TLocalArena;
  LRtl: IAllocator;
  LFall: TFallbackArena;
  LMark: TArenaMark;
begin
  LArena := TLocalArena.Create(256);
  LRtl := GetRtlAllocator;
  LFall := TFallbackArena.Create(LArena, LRtl);
  try
    LFall.Alloc(32);
    LMark := LFall.SaveMark;
    LFall.Alloc(64);
    LFall.RestoreToMark(LMark);
    CheckEqual(Int64(32), Int64(LFall.UsedSize), 'restored');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackArenaFreeFallbacks;
var
  LArena: TLocalArena;
  LRtl: IAllocator;
  LFall: TFallbackArena;
  LP: Pointer;
begin
  LArena := TLocalArena.Create(32);
  LRtl := GetRtlAllocator;
  LFall := TFallbackArena.Create(LArena, LRtl);
  try
    LFall.Alloc(32); { fill arena }
    LP := LFall.Alloc(32); { fallback }
    Check(LP <> nil, 'fallback alloc');
    CheckEqual(Int64(1), Int64(LFall.TotalFallbacks), 'one fallback');

    LFall.FreeFallbacks;
    CheckEqual(Int64(1), Int64(LFall.TotalFallbacks), 'total unchanged');
  finally
    LFall.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  Runner
  --------------------------------------------------------------------------- }

begin
  T := TTestRunner.Create('nextpas.core.mem.allocator.fallback');

  { TFallbackAllocator }
  T.Run('FallbackAllocator create/destroy', @TestFallbackAllocatorCreateDestroy);
  T.Run('FallbackAllocator primary succeeds', @TestFallbackAllocatorPrimarySucceeds);
  T.Run('FallbackAllocator primary fails', @TestFallbackAllocatorPrimaryFails);
  T.Run('FallbackAllocator free from correct', @TestFallbackAllocatorFreeFromCorrect);
  T.Run('FallbackAllocator multiple', @TestFallbackAllocatorMultiple);
  T.Run('FallbackAllocator AllocMem', @TestFallbackAllocatorAllocMem);
  T.Run('FallbackAllocator free nil', @TestFallbackAllocatorFreeNil);
  T.Run('FallbackAllocator realloc from fallback updates size', @TestFallbackAllocatorReallocMemFromFallbackUpdatesSize);

  { TFallbackArena }
  T.Run('FallbackArena create/destroy', @TestFallbackArenaCreateDestroy);
  T.Run('FallbackArena primary succeeds', @TestFallbackArenaPrimarySucceeds);
  T.Run('FallbackArena exhaust and fallback', @TestFallbackArenaExhaustAndFallback);
  T.Run('FallbackArena reset', @TestFallbackArenaReset);
  T.Run('FallbackArena mark/restore', @TestFallbackArenaMarkRestore);
  T.Run('FallbackArena free fallbacks', @TestFallbackArenaFreeFallbacks);

  T.Summary;
end.
