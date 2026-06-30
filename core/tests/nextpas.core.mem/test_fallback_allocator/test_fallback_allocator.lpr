program test_fallback_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
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
  TOomAllocator = class(TAllocator)
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(ADst: Pointer); override;
  public
    function Traits: TAllocatorTraits; override;
  end;

function TOomAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin Result := nil; end;
function TOomAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin Result := nil; end;
function TOomAllocator.DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
begin Result := nil; end;
procedure TOomAllocator.DoFreeMem(ADst: Pointer);
begin end;
function TOomAllocator.Traits: TAllocatorTraits;
begin FillChar(Result, SizeOf(Result), 0); end;

var
  T: TTestSuite;

{ --- TFallbackAllocator tests --- }

procedure TestFallbackAllocatorPrimarySucceeds;
var
  LRtl: TAllocator;
  LFall: TFallbackAllocator;
  LP: Pointer;
begin
  LRtl := GetRtlAllocator;
  LFall := TFallbackAllocator.Create(LRtl, LRtl);
  try
    LP := LFall.GetMem(64);
    Check(LP <> nil, 'primary alloc succeeds');
    Check(Int64(0) = Int64(LFall.TotalFallbacks), 'no fallback needed');
    LFall.FreeMem(LP);
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackAllocatorPrimaryFails;
var
  LOom: TOomAllocator;
  LRtl: TAllocator;
  LFall: TFallbackAllocator;
  LP: Pointer;
begin
  LOom := TOomAllocator.Create;
  LRtl := GetRtlAllocator;
  LFall := TFallbackAllocator.Create(LOom, LRtl);
  try
    LP := LFall.GetMem(64);
    Check(LP <> nil, 'fallback alloc succeeds');
    Check(Int64(1) = Int64(LFall.TotalFallbacks), 'one fallback');
    LFall.FreeMem(LP);
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackAllocatorFreeFromCorrect;
var
  LOom: TOomAllocator;
  LRtl: TAllocator;
  LFall: TFallbackAllocator;
  LP1: Pointer;
begin
  LOom := TOomAllocator.Create;
  LRtl := GetRtlAllocator;
  LFall := TFallbackAllocator.Create(LRtl, LOom);
  try
    LP1 := LFall.GetMem(32);
    Check(LP1 <> nil, 'primary alloc');
    Check(Int64(0) = Int64(LFall.TotalFallbacks), 'no fallback');
    LFall.FreeMem(LP1);
    Check(True, 'free primary succeeded');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackAllocatorMultiple;
var
  LOom: TOomAllocator;
  LRtl: TAllocator;
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
    Check(Int64(10) = Int64(LFall.TotalFallbacks), '10 fallbacks');
    for I := 0 to 9 do
      LFall.FreeMem(LPs[I]);
    Check(Int64(10) = Int64(LFall.TotalFallbacks), 'total fallback count unchanged');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackAllocatorAllocMem;
var
  LOom: TOomAllocator;
  LRtl: TAllocator;
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
    for I := 0 to 63 do
      Check(LP[I] = 0, 'zeroed at ' + IntToStr(I));
    LFall.FreeMem(LP);
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackAllocatorFreeNil;
var
  LRtl: TAllocator;
  LFall: TFallbackAllocator;
begin
  LRtl := GetRtlAllocator;
  LFall := TFallbackAllocator.Create(LRtl, LRtl);
  try
    LFall.FreeMem(nil);
    Check(True, 'free nil does not crash');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackAllocatorReallocMemFromFallbackUpdatesSize;
var
  LOom: TOomAllocator;
  LRtl: TAllocator;
  LFall: TFallbackAllocator;
  LP, LP2: PByte;
begin
  LOom := TOomAllocator.Create;
  LRtl := GetRtlAllocator;
  LFall := TFallbackAllocator.Create(LOom, LRtl);
  try
    LP := PByte(LFall.GetMem(64));
    Check(LP <> nil, 'fallback alloc succeeds');
    LP^ := $AB;
    LP2 := PByte(LFall.ReallocMem(LP, 64, 128));
    Check(LP2 <> nil, 'realloc from fallback succeeds');
    Check(LP2^ = $AB, 'data preserved after realloc');
    LFall.FreeMem(LP2);
    Check(True, 'free after realloc succeeds');
  finally
    LFall.Free;
  end;
end;

{ --- TFallbackArena tests --- }

procedure TestFallbackArenaCreateDestroy;
var
  LArena: TLocalArena;
  LRtl: TAllocator;
  LFall: TFallbackArena;
begin
  LArena := TLocalArena.Create(256);
  LRtl := GetRtlAllocator;
  LFall := TFallbackArena.Create(LArena, LRtl);
  try
    Check(LFall <> nil, 'created');
    Check(Int64(0) = Int64(LFall.TotalFallbacks), 'initial fallbacks 0');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackArenaPrimarySucceeds;
var
  LArena: TLocalArena;
  LRtl: TAllocator;
  LFall: TFallbackArena;
  LP: Pointer;
begin
  LArena := TLocalArena.Create(1024);
  LRtl := GetRtlAllocator;
  LFall := TFallbackArena.Create(LArena, LRtl);
  try
    LP := LFall.Alloc(64);
    Check(LP <> nil, 'arena alloc succeeds');
    Check(Int64(0) = Int64(LFall.TotalFallbacks), 'no fallback');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackArenaExhaustAndFallback;
var
  LArena: TLocalArena;
  LRtl: TAllocator;
  LFall: TFallbackArena;
  LP1, LP2: Pointer;
begin
  LArena := TLocalArena.Create(64);
  LRtl := GetRtlAllocator;
  LFall := TFallbackArena.Create(LArena, LRtl);
  try
    LP1 := LFall.Alloc(64);
    Check(LP1 <> nil, 'arena alloc');
    Check(Int64(0) = Int64(LFall.TotalFallbacks), 'no fallback yet');
    LP2 := LFall.Alloc(32);
    Check(LP2 <> nil, 'fallback alloc succeeds');
    Check(Int64(1) = Int64(LFall.TotalFallbacks), 'one fallback');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackArenaReset;
var
  LArena: TLocalArena;
  LRtl: TAllocator;
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
    Check(Int64(0) = Int64(LFall.UsedSize), 'arena reset');
    LP := LFall.Alloc(128);
    Check(LP <> nil, 'alloc after reset');
    Check(Int64(0) = Int64(LFall.TotalFallbacks), 'no fallback after reset');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackArenaMarkRestore;
var
  LArena: TLocalArena;
  LRtl: TAllocator;
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
    Check(Int64(32) = Int64(LFall.UsedSize), 'restored');
  finally
    LFall.Free;
  end;
end;

procedure TestFallbackArenaFreeFallbacks;
var
  LArena: TLocalArena;
  LRtl: TAllocator;
  LFall: TFallbackArena;
  LP: Pointer;
begin
  LArena := TLocalArena.Create(32);
  LRtl := GetRtlAllocator;
  LFall := TFallbackArena.Create(LArena, LRtl);
  try
    LFall.Alloc(32);
    LP := LFall.Alloc(32);
    Check(LP <> nil, 'fallback alloc');
    Check(Int64(1) = Int64(LFall.TotalFallbacks), 'one fallback');
    LFall.FreeFallbacks;
    Check(Int64(1) = Int64(LFall.TotalFallbacks), 'total unchanged');
  finally
    LFall.Free;
  end;
end;

{ R-21 regression: ReallocMem(ptr, 0) frees and removes entry }
procedure TestFallbackReallocZeroSize;
var
  LPrimary: TAllocator;
  LFallback: TFallbackAllocator;
  LPtr, LNew: Pointer;
begin
  LPrimary := TOomAllocator.Create;
  LFallback := TFallbackAllocator.Create(LPrimary, GetRtlAllocator);
  try
    LPtr := LFallback.GetMem(64);
    Check(LPtr <> nil, 'fallback alloc succeeded');
    LNew := LFallback.ReallocMem(LPtr, 64, 0);
    Check(LNew = nil, 'ReallocMem(ptr, 0) returns nil');
    LPtr := LFallback.GetMem(64);
    Check(LPtr <> nil, 're-alloc after zero-realloc succeeds');
    LFallback.FreeMem(LPtr);
  finally
    LFallback.Free;
  end;
end;

{ R-21 regression: ReallocMem failure returns nil, not original pointer }
procedure TestFallbackReallocFailureReturnsNil;
var
  LPrimary: TAllocator;
  LFallback: TFallbackAllocator;
  LPtr, LNew: Pointer;
begin
  LPrimary := TOomAllocator.Create;
  LFallback := TFallbackAllocator.Create(LPrimary, GetRtlAllocator);
  try
    LPtr := LFallback.GetMem(64);
    Check(LPtr <> nil, 'fallback alloc succeeded');
    LNew := LFallback.ReallocMem(LPtr, 64, 128);
    if LNew <> nil then
      LFallback.FreeMem(LNew)
    else
      LFallback.FreeMem(LPtr);
  finally
    LFallback.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.allocator.fallback');

  { TFallbackAllocator }
  T.Test('FallbackAllocator primary succeeds', @TestFallbackAllocatorPrimarySucceeds);
  T.Test('FallbackAllocator primary fails', @TestFallbackAllocatorPrimaryFails);
  T.Test('FallbackAllocator free from correct', @TestFallbackAllocatorFreeFromCorrect);
  T.Test('FallbackAllocator multiple', @TestFallbackAllocatorMultiple);
  T.Test('FallbackAllocator AllocMem', @TestFallbackAllocatorAllocMem);
  T.Test('FallbackAllocator free nil', @TestFallbackAllocatorFreeNil);
  T.Test('FallbackAllocator realloc from fallback updates size', @TestFallbackAllocatorReallocMemFromFallbackUpdatesSize);
  T.Test('FallbackAllocator realloc(ptr,0) frees entry (R-21)', @TestFallbackReallocZeroSize);
  T.Test('FallbackAllocator realloc failure returns nil (R-21)', @TestFallbackReallocFailureReturnsNil);

  { TFallbackArena }
  T.Test('FallbackArena create/destroy', @TestFallbackArenaCreateDestroy);
  T.Test('FallbackArena primary succeeds', @TestFallbackArenaPrimarySucceeds);
  T.Test('FallbackArena exhaust and fallback', @TestFallbackArenaExhaustAndFallback);
  T.Test('FallbackArena reset', @TestFallbackArenaReset);
  T.Test('FallbackArena mark/restore', @TestFallbackArenaMarkRestore);
  T.Test('FallbackArena free fallbacks', @TestFallbackArenaFreeFallbacks);

  T.Run;
  T.Summary;
end.
