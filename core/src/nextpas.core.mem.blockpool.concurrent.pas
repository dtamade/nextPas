unit nextpas.core.mem.blockpool.concurrent;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base.utils,
  nextpas.core.mem.base,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.mutex,
  nextpas.core.mem.error;

type
  {**
   * TBlockPoolConcurrent
   *
   * @desc Thread-safe wrapper for IBlockPool (mutex-protected).
   *}
  TBlockPoolConcurrent = class(TInterfacedObject, IBlockPool, IBlockPoolBatch)
  private
    FInner: IBlockPool;
    FLock: TMemMutex;
  public
    constructor Create(aInner: IBlockPool); overload;
    constructor Create(aBlockSize, aCapacity: SizeUInt; aAlignment: SizeUInt = DEFAULT_ALIGNMENT); overload;
    destructor Destroy; override;

    { IBlockPool }
    function Acquire: Pointer;
    function TryAcquire(out aPtr: Pointer): Boolean;
    procedure Release(aPtr: Pointer);
    procedure Reset;
    function BlockSize: SizeUInt;
    function Capacity: SizeUInt;
    function Available: SizeUInt;
    function InUse: SizeUInt;

    { IBlockPoolBatch }
    function AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
    procedure ReleaseN(const aPtrs: array of Pointer; aCount: Integer);

    property Inner: IBlockPool read FInner;
  end;

implementation

{ TBlockPoolConcurrent }

constructor TBlockPoolConcurrent.Create(aInner: IBlockPool);
begin
  inherited Create;
  if aInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TBlockPoolConcurrent: inner pool cannot be nil');
  FLock.Init;
  FInner := aInner;
end;

constructor TBlockPoolConcurrent.Create(aBlockSize, aCapacity: SizeUInt; aAlignment: SizeUInt);
begin
  Create(TBlockPool.Create(aBlockSize, aCapacity, aAlignment));
end;

destructor TBlockPoolConcurrent.Destroy;
begin
  FLock.Acquire;
  try
    FInner := nil;
  finally
    FLock.Release;
  end;
  FLock.Done;
  inherited Destroy;
end;

function TBlockPoolConcurrent.Acquire: Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.Acquire;
  finally
    FLock.Release;
  end;
end;

function TBlockPoolConcurrent.TryAcquire(out aPtr: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.TryAcquire(aPtr);
  finally
    FLock.Release;
  end;
end;

function TBlockPoolConcurrent.AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
var
  LBatch: IBlockPoolBatch;
  LIdx: Integer;
  LPtr: Pointer;
begin
  Result := 0;
  if aCount <= 0 then Exit(0);
  FLock.Acquire;
  try
    if aCount > Length(aPtrs) then
      aCount := Length(aPtrs);
    if Supports(FInner, IBlockPoolBatch, LBatch) then
      Exit(LBatch.AcquireN(aPtrs, aCount));
    for LIdx := 0 to aCount - 1 do
    begin
      if LIdx > High(aPtrs) then
        Break;
      LPtr := FInner.Acquire;
      if LPtr = nil then
        Break;
      aPtrs[LIdx] := LPtr;
      Inc(Result);
    end;
  finally
    FLock.Release;
  end;
end;

procedure TBlockPoolConcurrent.ReleaseN(const aPtrs: array of Pointer; aCount: Integer);
var
  LBatch: IBlockPoolBatch;
  LIdx: Integer;
begin
  if aCount <= 0 then Exit;
  FLock.Acquire;
  try
    if aCount > Length(aPtrs) then
      aCount := Length(aPtrs);
    if Supports(FInner, IBlockPoolBatch, LBatch) then
    begin
      LBatch.ReleaseN(aPtrs, aCount);
      Exit;
    end;
    for LIdx := 0 to aCount - 1 do
    begin
      if LIdx > High(aPtrs) then
        Break;
      FInner.Release(aPtrs[LIdx]);
    end;
  finally
    FLock.Release;
  end;
end;

procedure TBlockPoolConcurrent.Release(aPtr: Pointer);
begin
  FLock.Acquire;
  try
    FInner.Release(aPtr);
  finally
    FLock.Release;
  end;
end;

procedure TBlockPoolConcurrent.Reset;
begin
  FLock.Acquire;
  try
    FInner.Reset;
  finally
    FLock.Release;
  end;
end;

function TBlockPoolConcurrent.BlockSize: SizeUInt;
begin
  Result := FInner.BlockSize;
end;

function TBlockPoolConcurrent.Capacity: SizeUInt;
begin
  Result := FInner.Capacity;
end;

function TBlockPoolConcurrent.Available: SizeUInt;
begin
  Result := FInner.Available;
end;

function TBlockPoolConcurrent.InUse: SizeUInt;
begin
  Result := FInner.InUse;
end;

end.
