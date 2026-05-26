unit nextpas.core.mem.blockpool.concurrent;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.sync,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.layout,
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
    FLock: IMutex;
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

  {**
   * TArenaConcurrent
   *
   * @desc Thread-safe wrapper for IArena (mutex-protected).
   *}
  TArenaConcurrent = class(TInterfacedObject, IArena)
  private
    FInner: IArena;
    FLock: IMutex;
  public
    constructor Create(aInner: IArena); overload;
    constructor Create(aTotalSize: SizeUInt); overload;
    destructor Destroy; override;

    { IArena }
    function Alloc(const aLayout: TMemLayout): TAllocResult;
    function AllocZeroed(const aLayout: TMemLayout): TAllocResult;
    function SaveMark: TArenaMarker;
    procedure RestoreToMark(aMark: TArenaMarker);
    procedure Reset;
    function TotalSize: SizeUInt;
    function UsedSize: SizeUInt;
    function RemainingSize: SizeUInt;

    property Inner: IArena read FInner;
  end;

implementation

{ TBlockPoolConcurrent }

constructor TBlockPoolConcurrent.Create(aInner: IBlockPool);
begin
  inherited Create;
  if aInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TBlockPoolConcurrent: inner pool cannot be nil');
  FLock := Mutex;
  FInner := aInner;
end;

constructor TBlockPoolConcurrent.Create(aBlockSize, aCapacity: SizeUInt; aAlignment: SizeUInt);
begin
  Create(TBlockPool.Create(aBlockSize, aCapacity, aAlignment));
end;

destructor TBlockPoolConcurrent.Destroy;
begin
  if FLock <> nil then
    FLock.Acquire;
  try
    FInner := nil;
  finally
    if FLock <> nil then
      FLock.Release;
  end;
  FLock := nil;
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

{ TArenaConcurrent }

constructor TArenaConcurrent.Create(aInner: IArena);
begin
  inherited Create;
  if aInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TArenaConcurrent: inner arena cannot be nil');
  FLock := Mutex;
  FInner := aInner;
end;

constructor TArenaConcurrent.Create(aTotalSize: SizeUInt);
begin
  Create(TArena.Create(aTotalSize));
end;

destructor TArenaConcurrent.Destroy;
begin
  if FLock <> nil then
    FLock.Acquire;
  try
    FInner := nil;
  finally
    if FLock <> nil then
      FLock.Release;
  end;
  FLock := nil;
  inherited Destroy;
end;

function TArenaConcurrent.Alloc(const aLayout: TMemLayout): TAllocResult;
begin
  FLock.Acquire;
  try
    Result := FInner.Alloc(aLayout);
  finally
    FLock.Release;
  end;
end;

function TArenaConcurrent.AllocZeroed(const aLayout: TMemLayout): TAllocResult;
begin
  FLock.Acquire;
  try
    Result := FInner.AllocZeroed(aLayout);
  finally
    FLock.Release;
  end;
end;

function TArenaConcurrent.SaveMark: TArenaMarker;
begin
  FLock.Acquire;
  try
    Result := FInner.SaveMark;
  finally
    FLock.Release;
  end;
end;

procedure TArenaConcurrent.RestoreToMark(aMark: TArenaMarker);
begin
  FLock.Acquire;
  try
    FInner.RestoreToMark(aMark);
  finally
    FLock.Release;
  end;
end;

procedure TArenaConcurrent.Reset;
begin
  FLock.Acquire;
  try
    FInner.Reset;
  finally
    FLock.Release;
  end;
end;

function TArenaConcurrent.TotalSize: SizeUInt;
begin
  Result := FInner.TotalSize;
end;

function TArenaConcurrent.UsedSize: SizeUInt;
begin
  Result := FInner.UsedSize;
end;

function TArenaConcurrent.RemainingSize: SizeUInt;
begin
  Result := FInner.RemainingSize;
end;

end.
