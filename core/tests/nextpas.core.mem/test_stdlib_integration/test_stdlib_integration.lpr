program test_stdlib_integration;
{**
 * M2-4 / STDLIB integration patterns (mem lane proof).
 *
 * Compiler and HTTP modules do not yet own nextpas.core.mem wiring.
 * This gate locks the *integration contracts* those modules should adopt:
 *   P1 Compiler unit: VirtualArena AST churn + Reset at unit boundary
 *   P2 HTTP request:  CreateDefaultArena / LocalArena Reset per request
 *   P3 Plugin inject: CreateArenaAllocator (IAllocator, Free no-op) consumer
 *   P4 Process heap:  DefaultHeap + DefaultAllocator same-heap long-lived
 *   P5 Collections:   THashMap inject DefaultAllocator (same process heap)
 *
 * Real compiler source rewiring remains a cross-module landing task;
 * HTTP product wire lives in http.mem + RequestArenaMiddleware.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.mem,
  nextpas.core.mem.intf,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.virtual,
  nextpas.core.mem.allocator.arena,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.growing,
  nextpas.core.mem.allocator.growing_ia,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.hashmap.intf;

var
  T: TTestSuite;
  LRunPassed: Boolean;

const
  NODE_SIZES: array[0..5] of SizeUInt = (24, 32, 48, 64, 128, 256);
  BODY_SIZES: array[0..3] of SizeUInt = (64, 256, 1024, 4096);

type
  { Minimal AST-like node header stored inside arena memory. }
  PAstNode = ^TAstNode;
  TAstNode = record
    Kind: LongWord;
    Child: PAstNode;
    Payload: array[0..15] of Byte;
  end;

  { IAllocator consumer mimicking a collection / parser plugin. }
  TArenaBackedBuilder = class
  private
    FAlloc: IAllocator;
    FCount: Integer;
  public
    constructor Create(const AAlloc: IAllocator);
    function Push(ASize: SizeUInt; ATag: Byte): Pointer;
    property Count: Integer read FCount;
  end;

constructor TArenaBackedBuilder.Create(const AAlloc: IAllocator);
begin
  inherited Create;
  FAlloc := AAlloc;
  FCount := 0;
end;

function TArenaBackedBuilder.Push(ASize: SizeUInt; ATag: Byte): Pointer;
begin
  Result := FAlloc.GetMem(ASize);
  if Result <> nil then
  begin
    PByte(Result)^ := ATag;
    Inc(FCount);
  end;
end;

procedure TestCompilerUnitVirtualArena;
var
  LArena: TVirtualArena;
  LRoot, LChild, LPrev: PAstNode;
  LPeak: SizeUInt;
  U, N: Integer;
  LPtr: Pointer;
  LSize: SizeUInt;
begin
  TVirtualArena_Init(LArena);
  try
    LPeak := 0;
    for U := 1 to 8 do
    begin
      LRoot := PAstNode(LArena.Alloc(SizeOf(TAstNode)));
      Check(LRoot <> nil, 'root node alloc');
      LRoot^.Kind := 1;
      LRoot^.Child := nil;
      LPrev := LRoot;
      for N := 1 to 200 do
      begin
        LSize := NODE_SIZES[N mod Length(NODE_SIZES)];
        if LSize < SizeOf(TAstNode) then
          LSize := SizeOf(TAstNode);
        LChild := PAstNode(LArena.Alloc(LSize));
        Check(LChild <> nil, 'child node alloc');
        LChild^.Kind := LongWord(N);
        LChild^.Child := nil;
        LPrev^.Child := LChild;
        LPrev := LChild;
        { also some non-pointer payload blobs (IR constants) }
        LPtr := LArena.AllocNoPointer(32);
        Check(LPtr <> nil, 'const blob');
        PByte(LPtr)^ := Byte(N);
      end;
      if LArena.PeakUsed > LPeak then
        LPeak := LArena.PeakUsed;
      Check(LRoot^.Child <> nil, 'tree linked');
      Check(LRoot^.Child^.Kind = 1, 'first child kind');
      { compilation unit end — drop entire AST }
      LArena.Reset;
      Check(LArena.TotalUsed = 0, 'unit Reset rewinds bump');
    end;
    Check(LPeak > 0, 'peak used observed');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestCompilerIAllocatorAdapter;
var
  LAlloc: IAllocator;
  LVA: TVirtualArenaAllocator;
  LBuilder: TArenaBackedBuilder;
  I: Integer;
  LPtr: Pointer;
begin
  { Hold only IAllocator so TInterfacedObject lifetime is clear. }
  LAlloc := TVirtualArenaAllocator.Create;
  LVA := LAlloc as TVirtualArenaAllocator;
  LBuilder := TArenaBackedBuilder.Create(LAlloc);
  try
    for I := 1 to 500 do
    begin
      LPtr := LBuilder.Push(NODE_SIZES[I mod Length(NODE_SIZES)], Byte(I));
      Check(LPtr <> nil, 'adapter GetMem');
    end;
    Check(LBuilder.Count = 500, 'builder count');
    LVA.Reset;
    { FreeMem is no-op by contract; Reset reclaims bulk }
    LPtr := LBuilder.Push(64, 1);
    Check(LPtr <> nil, 'alloc after Reset');
  finally
    LBuilder.Free;
    LAlloc := nil;
  end;
end;

procedure TestHttpRequestLocalArena;
var
  LArena: IArena;
  R: Integer;
  LHdr, LBody, LScratch: Pointer;
  LBodySize: SizeUInt;
  LUsedAfter: SizeUInt;
begin
  LArena := CreateDefaultArena(256 * 1024);
  Check(LArena <> nil, 'CreateDefaultArena');
  for R := 1 to 100 do
  begin
    LBodySize := BODY_SIZES[R mod Length(BODY_SIZES)];
    LHdr := LArena.Alloc(128);
    LBody := LArena.Alloc(LBodySize);
    LScratch := LArena.Alloc(64);
    Check(LHdr <> nil, 'req header');
    Check(LBody <> nil, 'req body');
    Check(LScratch <> nil, 'req scratch');
    PByte(LHdr)^ := Byte(R);
    PByte(LBody)^ := Byte(R xor $5A);
    Check(LArena.UsedSize > 0, 'used during request');
    LArena.Reset;
    LUsedAfter := LArena.UsedSize;
    Check(LUsedAfter = 0, 'request Reset clears used');
  end;
end;

procedure TestHttpArenaAllocatorPlugin;
var
  LAlloc: IAllocator;
  LBuilder: TArenaBackedBuilder;
  I: Integer;
  LPtr: Pointer;
  LCap: SizeUInt;
begin
  { CreateArenaAllocator: LocalArena backend, Free no-op — request inject path.
    200 * mixed body sizes need headroom past 128 KiB (was VirtualArena grow path). }
  LAlloc := CreateArenaAllocator(512 * 1024);
  Check(LAlloc <> nil, 'CreateArenaAllocator');
  Check(not LAlloc.Traits.SupportsRealloc, 'arena realloc unsupported');
  LBuilder := TArenaBackedBuilder.Create(LAlloc);
  try
    for I := 1 to 200 do
    begin
      LPtr := LBuilder.Push(BODY_SIZES[I mod Length(BODY_SIZES)], Byte(I));
      Check(LPtr <> nil, 'plugin alloc');
    end;
    Check(LBuilder.Count = 200, 'plugin count');
    { FreeMem is no-op — safe to call }
    LAlloc.FreeMem(LPtr);
  finally
    LBuilder.Free;
  end;

  { Capacity bound: LocalArena returns nil when full (VirtualArena would grow). }
  LCap := 512;
  LAlloc := CreateArenaAllocator(LCap);
  LPtr := LAlloc.GetMem(LCap);
  Check(LPtr <> nil, 'fill capacity');
  Check(LAlloc.GetMem(64) = nil, 'over capacity nil');
end;

procedure TestCreateVirtualArenaAllocatorFactory;
var
  LAlloc: IAllocator;
  LVA: TVirtualArenaAllocator;
  I: Integer;
  LPtr: Pointer;
begin
  LAlloc := CreateVirtualArenaAllocator;
  Check(LAlloc <> nil, 'CreateVirtualArenaAllocator');
  Check(LAlloc is TVirtualArenaAllocator, 'virtual backend');
  LVA := LAlloc as TVirtualArenaAllocator;
  for I := 1 to 100 do
  begin
    LPtr := LAlloc.GetMem(NODE_SIZES[I mod Length(NODE_SIZES)]);
    Check(LPtr <> nil, 'virtual GetMem');
  end;
  LVA.Reset;
  Check(LAlloc.GetMem(128) <> nil, 'after Reset');
end;

procedure TestProcessHeapSameRoot;
var
  LHeap: TGrowingAllocator;
  LPlugin: IAllocator;
  LPtrs: array[0..31] of Pointer;
  I: Integer;
begin
  LHeap := DefaultHeap;
  LPlugin := DefaultAllocator;
  Check(LHeap <> nil, 'DefaultHeap');
  Check(LPlugin <> nil, 'DefaultAllocator');
  Check(LHeap = DefaultGrowingAllocator, 'DefaultHeap alias');
  Check(LPlugin = GetGrowingIAllocator, 'plugin root Growing IAllocator');
  for I := 0 to High(LPtrs) do
  begin
    LPtrs[I] := LHeap.GetMem(64);
    Check(LPtrs[I] <> nil, 'long-lived heap alloc');
    PByte(LPtrs[I])^ := Byte(I);
  end;
  for I := 0 to High(LPtrs) do
  begin
    Check(PByte(LPtrs[I])^ = Byte(I), 'payload intact');
    LHeap.FreeMem(LPtrs[I], 64);
  end;
end;

procedure TestCollectionsDefaultAllocatorSameHeap;
type
  IIntMap = specialize IHashMap<Integer, Integer>;
  TIntMap = specialize THashMap<Integer, Integer>;
var
  LMap: IIntMap;
  LPlugin: IAllocator;
  LHeap: TGrowingAllocator;
  LPtr: Pointer;
  I: Integer;
  LVal: Integer;
begin
  { Collections default ctor → DefaultAllocator → Growing IAllocator root. }
  LPlugin := DefaultAllocator;
  LHeap := DefaultHeap;
  Check(LPlugin = GetGrowingIAllocator, 'collections inject root');

  LMap := TIntMap.Create(0, nil, nil, LPlugin);
  for I := 1 to 64 do
    LMap.Put(I, I * 10);
  Check(LMap.Count = 64, 'map count');
  Check(LMap.Get(32) = 320, 'map get');
  Check(LMap.TryGetValue(1, LVal) and (LVal = 10), 'map tryget');

  { Same-heap round-trip still holds while collection is live. }
  LPtr := LPlugin.GetMem(48);
  Check(LPtr <> nil, 'plugin alloc during map');
  LHeap.FreeMem(LPtr, 48);

  LMap := nil; { free buckets via DefaultAllocator }
  Check(True, 'collections + DefaultAllocator lifecycle');
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.stdlib_integration');
  T.Test('P1 compiler virtual arena unit', @TestCompilerUnitVirtualArena);
  T.Test('P1 compiler IAllocator adapter', @TestCompilerIAllocatorAdapter);
  T.Test('P2 HTTP request LocalArena', @TestHttpRequestLocalArena);
  T.Test('P3 HTTP CreateArenaAllocator plugin', @TestHttpArenaAllocatorPlugin);
  T.Test('P3b CreateVirtualArenaAllocator factory', @TestCreateVirtualArenaAllocatorFactory);
  T.Test('P4 process heap same root', @TestProcessHeapSameRoot);
  T.Test('P5 collections DefaultAllocator same-heap', @TestCollectionsDefaultAllocatorSameHeap);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
