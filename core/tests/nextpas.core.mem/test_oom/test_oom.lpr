program test_oom;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.exception,
  nextpas.core.testing,
  nextpas.core.mem.error,
  nextpas.core.mem.layout,
  nextpas.core.mem.alloc,
  nextpas.core.mem.allocator,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.blockpool.growable,
  nextpas.core.mem.arena.growable,
  nextpas.core.mem.pool.fixed,
  nextpas.core.mem.pool.fixed.growable,
  nextpas.core.mem.ring_buffer,
  nextpas.core.mem.stack_pool;

type
  TExceptionProc = procedure;

  TFailAllocator = class(nextpas.core.mem.allocator.TAllocator)
  protected
    function DoGetMem(aSize: SizeUInt): Pointer; override;
    function DoAllocMem(aSize: SizeUInt): Pointer; override;
    function DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; override;
    procedure DoFreeMem(aDst: Pointer); override;
  end;

  TFailAlloc = class(TAllocBase)
  protected
    function DoAlloc(aSize: SizeUInt; aAlign: SizeUInt): Pointer; override;
    procedure DoDealloc(aPtr: Pointer; aSize: SizeUInt; aAlign: SizeUInt); override;
  public
    constructor Create;
  end;

var
  T: TTestRunner;

function TFailAllocator.DoGetMem(aSize: SizeUInt): Pointer;
begin
  Result := nil;
end;

function TFailAllocator.DoAllocMem(aSize: SizeUInt): Pointer;
begin
  Result := nil;
end;

function TFailAllocator.DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  Result := nil;
end;

procedure TFailAllocator.DoFreeMem(aDst: Pointer);
begin
end;

constructor TFailAlloc.Create;
begin
  inherited Create(TAllocCaps.Default);
end;

function TFailAlloc.DoAlloc(aSize: SizeUInt; aAlign: SizeUInt): Pointer;
begin
  Result := nil;
end;

procedure TFailAlloc.DoDealloc(aPtr: Pointer; aSize: SizeUInt; aAlign: SizeUInt);
begin
end;

function NewFailAllocator: nextpas.core.mem.allocator.IAllocator;
begin
  Result := TFailAllocator.Create as nextpas.core.mem.allocator.IAllocator;
end;

function NewFailAlloc: IAlloc;
begin
  Result := TFailAlloc.Create as IAlloc;
end;

procedure CheckRaisesCanonicalOutOfMemory(aProc: TExceptionProc; const aName: string);
var
  LCaughtOom: Boolean;
  LCaughtAlloc: Boolean;
begin
  LCaughtOom := False;
  LCaughtAlloc := False;

  try
    aProc;
  except
    on E: EOutOfMemoryError do
      LCaughtOom := True;
    on E: EAllocError do
      LCaughtAlloc := True;
  end;

  Check(LCaughtOom, aName + ' raises canonical OOM');
  Check(not LCaughtAlloc, aName + ' is not caught by non-OOM EAllocError');
end;

procedure CheckRaisesAllocError(aProc: TExceptionProc; aExpected: TAllocError; const aName: string);
var
  LCaughtExpected: Boolean;
  LCaughtOom: Boolean;
begin
  LCaughtExpected := False;
  LCaughtOom := False;

  try
    aProc;
  except
    on E: EOutOfMemoryError do
      LCaughtOom := True;
    on E: EAllocError do
      LCaughtExpected := E.Error = aExpected;
  end;

  Check(LCaughtExpected, aName + ' raises expected allocation error');
  Check(not LCaughtOom, aName + ' is not canonical OOM');
end;

procedure RaiseAllocResultOom;
begin
  TAllocResult.Err(aeOutOfMemory).ExpectPtr('alloc result');
end;

procedure RaiseBlockPoolTotalSizeOverflow;
var
  LPool: TBlockPool;
begin
  LPool := nil;
  try
    LPool := TBlockPool.Create((High(SizeUInt) div 2) + 1, 2);
  finally
    LPool.Free;
  end;
end;

procedure RaiseBlockPoolArenaAllocationOverflow;
var
  LArena: nextpas.core.mem.blockpool.TArena;
begin
  LArena := nil;
  try
    LArena := nextpas.core.mem.blockpool.TArena.Create(High(SizeUInt));
  finally
    LArena.Free;
  end;
end;

procedure RaiseGrowingBlockPoolAllocatorOom;
var
  LConfig: TGrowingBlockPoolConfig;
  LPool: TGrowingBlockPool;
begin
  LConfig := TGrowingBlockPoolConfig.Default(16, 1);
  LConfig.Allocator := NewFailAlloc;
  LPool := nil;
  try
    LPool := TGrowingBlockPool.Create(LConfig);
  finally
    LPool.Free;
  end;
end;

procedure RaiseGrowingArenaAllocatorOom;
var
  LConfig: TGrowingArenaConfig;
  LArena: TGrowingArena;
begin
  LConfig := TGrowingArenaConfig.Default(16);
  LConfig.Allocator := NewFailAlloc;
  LArena := nil;
  try
    LArena := TGrowingArena.Create(LConfig);
  finally
    LArena.Free;
  end;
end;

procedure RaiseFixedPoolAllocatorOom;
var
  LPool: TFixedPool;
begin
  LPool := nil;
  try
    LPool := TFixedPool.Create(16, 1, 16, NewFailAllocator);
  finally
    LPool.Free;
  end;
end;

procedure RaiseGrowingFixedPoolAllocatorOom;
var
  LConfig: TGrowingFixedPoolConfig;
  LPool: TGrowingFixedPool;
begin
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.BlockSize := 16;
  LConfig.InitialCapacity := 1;
  LConfig.GrowthKind := gkGeometric;
  LConfig.GrowthFactor := 2.0;
  LConfig.Allocator := NewFailAllocator;

  LPool := nil;
  try
    LPool := TGrowingFixedPool.Create(LConfig);
  finally
    LPool.Free;
  end;
end;

procedure RaiseRingBufferAllocatorOom;
var
  LRing: TRingBuffer;
begin
  LRing := nil;
  try
    LRing := TRingBuffer.Create(1, 1, NewFailAllocator);
  finally
    LRing.Free;
  end;
end;

procedure RaiseStackPoolAllocatorOom;
var
  LPool: TStackPool;
begin
  LPool := nil;
  try
    LPool := TStackPool.Create(1, NewFailAllocator);
  finally
    LPool.Free;
  end;
end;

procedure TestAllocResultOomUsesCanonicalRoot;
begin
  CheckRaisesCanonicalOutOfMemory(@RaiseAllocResultOom, 'TAllocResult.ExpectPtr');
end;

procedure TestBlockPoolOverflowContracts;
begin
  CheckRaisesAllocError(@RaiseBlockPoolTotalSizeOverflow, aeInvalidLayout, 'TBlockPool.Create layout overflow');
  CheckRaisesCanonicalOutOfMemory(@RaiseBlockPoolArenaAllocationOverflow, 'TArena.Create allocation overflow');
end;

procedure TestGrowableMemOomUsesCanonicalRoot;
begin
  CheckRaisesCanonicalOutOfMemory(@RaiseGrowingBlockPoolAllocatorOom, 'TGrowingBlockPool.Create');
  CheckRaisesCanonicalOutOfMemory(@RaiseGrowingArenaAllocatorOom, 'TGrowingArena.Create');
  CheckRaisesCanonicalOutOfMemory(@RaiseGrowingFixedPoolAllocatorOom, 'TGrowingFixedPool.Create');
end;

procedure TestAllocatorBackedMemOomUsesCanonicalRoot;
begin
  CheckRaisesCanonicalOutOfMemory(@RaiseFixedPoolAllocatorOom, 'TFixedPool.Create');
  CheckRaisesCanonicalOutOfMemory(@RaiseRingBufferAllocatorOom, 'TRingBuffer.Create');
  CheckRaisesCanonicalOutOfMemory(@RaiseStackPoolAllocatorOom, 'TStackPool.Create');
end;

procedure TestNonOomAllocErrorRemainsEAllocError;
var
  LCaughtAlloc: Boolean;
begin
  LCaughtAlloc := False;
  try
    raise EAllocError.Create(aeInvalidLayout, 'invalid layout');
  except
    on E: EAllocError do
      LCaughtAlloc := True;
  end;

  Check(LCaughtAlloc, 'non-OOM allocation errors remain EAllocError');
end;

procedure TestCapacityExhaustedUsesResourceExhaustedAllocLeaf;
var
  LCaughtCapacity: Boolean;
  LCaughtInvalidPointer: Boolean;
begin
  LCaughtCapacity := False;
  LCaughtInvalidPointer := False;

  try
    TAllocResult.Err(aeCapacityExhausted).ExpectPtr('fixed pool');
  except
    on E: EInvalidPointer do
      LCaughtInvalidPointer := True;
    on E: EAllocError do
    begin
      LCaughtCapacity := E.Error = aeCapacityExhausted;
      Check(E.Category = ecResourceExhausted,
        'capacity exhaustion should keep resource-exhausted category');
    end;
  end;

  Check(LCaughtCapacity,
    'capacity exhaustion should remain catchable as EAllocError with aeCapacityExhausted');
  Check(not LCaughtInvalidPointer,
    'capacity exhaustion should not be reported as invalid pointer');
end;

procedure CheckStateAllocErrorUsesInvalidOperationLeaf(aError: TAllocError;
  const aName: string);
var
  LCaughtAlloc: Boolean;
  LCaughtInvalidPointer: Boolean;
begin
  LCaughtAlloc := False;
  LCaughtInvalidPointer := False;

  try
    TAllocResult.Err(aError).ExpectPtr(aName);
  except
    on E: EInvalidPointer do
      LCaughtInvalidPointer := True;
    on E: EAllocError do
    begin
      LCaughtAlloc := E.Error = aError;
      Check(E.Category = ecInvalidOperation,
        aName + ' should keep invalid-operation category');
    end;
  end;

  Check(LCaughtAlloc,
    aName + ' should remain catchable as EAllocError with original code');
  Check(not LCaughtInvalidPointer,
    aName + ' should not be reported as invalid pointer');
end;

procedure TestStateAllocErrorsUseInvalidOperationLeaf;
begin
  CheckStateAllocErrorUsesInvalidOperationLeaf(aePoolClosed, 'pool closed');
  CheckStateAllocErrorUsesInvalidOperationLeaf(aeReallocNotSupported, 'realloc not supported');
end;

procedure TestAllocResultErrAeNoneFailsClosed;
var
  LResult: TAllocResult;
  LCaught: Boolean;
begin
  LResult := TAllocResult.Err(aeNone);
  Check(not LResult.IsOk, 'Err(aeNone) should not masquerade as Ok');
  Check(LResult.IsErr, 'Err(aeNone) should remain an error result');
  Check(LResult.Error = aeInternalError,
    'Err(aeNone) should normalize to internal error');

  LCaught := False;
  try
    LResult.ExpectPtr('invalid alloc result');
  except
    on E: EAllocError do
    begin
      LCaught := E.Error = aeInternalError;
      Check(E.Category = ecInternal,
        'Err(aeNone) ExpectPtr should raise internal category');
    end;
  end;
  Check(LCaught, 'Err(aeNone) ExpectPtr should fail closed');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.oom');
  T.Run('alloc result OOM uses canonical root', @TestAllocResultOomUsesCanonicalRoot);
  T.Run('blockpool overflow contracts', @TestBlockPoolOverflowContracts);
  T.Run('growable mem OOM uses canonical root', @TestGrowableMemOomUsesCanonicalRoot);
  T.Run('allocator-backed mem OOM uses canonical root', @TestAllocatorBackedMemOomUsesCanonicalRoot);
  T.Run('non-OOM allocation error remains EAllocError', @TestNonOomAllocErrorRemainsEAllocError);
  T.Run('capacity exhaustion uses resource-exhausted alloc leaf', @TestCapacityExhaustedUsesResourceExhaustedAllocLeaf);
  T.Run('state allocation errors use invalid-operation leaf', @TestStateAllocErrorsUseInvalidOperationLeaf);
  T.Run('Err(aeNone) fails closed', @TestAllocResultErrAeNoneFailsClosed);
  T.Summary;
end.
