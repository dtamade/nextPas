unit nextpas.core.mem.compat;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.mem.intf,
  nextpas.core.mem.pool.fixed,
  nextpas.core.mem.stack_pool,
  nextpas.core.mem.pool.slab,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.layout,
  nextpas.core.mem.error;

type
  { Compatibility layer for legacy mem pool and adapter surfaces.
    New code should use canonical nextpas.core.mem.* units directly. }
  IAllocator = nextpas.core.mem.intf.IAllocator;

  TMemPool = nextpas.core.mem.pool.fixed.TFixedPool;
  TMemPoolConfig = nextpas.core.mem.pool.fixed.TFixedPoolConfig;
  EMemPoolError = nextpas.core.mem.pool.fixed.EMemFixedPoolError;
  EMemPoolInvalidPointer = nextpas.core.mem.pool.fixed.EMemFixedPoolInvalidPointer;
  EMemPoolDoubleFree = nextpas.core.mem.pool.fixed.EMemFixedPoolDoubleFree;

  TStackPool = nextpas.core.mem.stack_pool.TStackPool;
  TStackPoolConfig = nextpas.core.mem.stack_pool.TStackPoolConfig;
  TSlabPool = nextpas.core.mem.pool.slab.TSlabPool;
  TSlabPoolStats = nextpas.core.mem.pool.slab.TSlabPoolStats;

  IBlockPool = nextpas.core.mem.blockpool.IBlockPool;
  IBlockPoolBatch = nextpas.core.mem.blockpool.IBlockPoolBatch;
  IArena = nextpas.core.mem.blockpool.IArena;
  TArenaMarker = nextpas.core.mem.blockpool.TArenaMarker;
  TMemLayout = nextpas.core.mem.layout.TMemLayout;
  TAllocResult = nextpas.core.mem.error.TAllocResult;

  IMemPool = interface
    ['{B03C5A4C-89D9-462E-8F01-3A4C3E1B7F0B}']
    function Alloc: Pointer;
    function TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean;
    procedure Free(APtr: Pointer);
    procedure Reset;
    function GetBlockSize: SizeUInt;
    function GetCapacity: Integer;
    function GetAllocatedCount: Integer;
  end;

  IStackPool = interface
    ['{9B1F8A19-3A7E-4F89-9D09-CA3CF57C52B8}']
    function Alloc(ASize: SizeUInt; AAlignment: SizeUInt = SizeOf(Pointer)): Pointer;
    function TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean;
    procedure Reset;
    procedure RestoreState(AOffset: SizeUInt);
    function GetTotalSize: SizeUInt;
    function GetOffset: SizeUInt;
  end;

  ISlabPool = interface
    ['{5C82C90D-7E8D-46C7-8B4E-4E8F3E7E8D1F}']
    function Alloc(ASize: SizeUInt): Pointer;
    function TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean;
    procedure Free(APtr: Pointer);
    procedure Reset;
  end;

  TMemPoolAdapter = class(TInterfacedObject, IMemPool)
  private
    FPool: TMemPool;
  public
    constructor Create(aPool: TMemPool);
    function Alloc: Pointer;
    function TryAlloc(out aPtr: Pointer; aSize: SizeUInt): Boolean;
    procedure Free(aPtr: Pointer);
    procedure Reset;
    function GetBlockSize: SizeUInt;
    function GetCapacity: Integer;
    function GetAllocatedCount: Integer;

    property Pool: TMemPool read FPool;
  end;

  TStackPoolAdapter = class(TInterfacedObject, IStackPool)
  private
    FPool: TStackPool;
  public
    constructor Create(aPool: TStackPool);
    function Alloc(aSize: SizeUInt; aAlignment: SizeUInt = SizeOf(Pointer)): Pointer;
    function TryAlloc(out aPtr: Pointer; aSize: SizeUInt): Boolean;
    procedure Reset;
    procedure RestoreState(aOffset: SizeUInt);
    function GetTotalSize: SizeUInt;
    function GetOffset: SizeUInt;

    property Pool: TStackPool read FPool;
  end;

  TSlabPoolAdapter = class(TInterfacedObject, ISlabPool)
  private
    FPool: TSlabPool;
  public
    constructor Create(aPool: TSlabPool);
    function Alloc(aSize: SizeUInt): Pointer;
    function TryAlloc(out aPtr: Pointer; aSize: SizeUInt): Boolean;
    procedure Free(aPtr: Pointer);
    procedure Reset;

    property Pool: TSlabPool read FPool;
  end;

  TMemPoolToBlockPoolAdapter = class(TInterfacedObject, IBlockPool, IBlockPoolBatch)
  private
    FPool: IMemPool;
  public
    constructor Create(aPool: IMemPool);
    function Acquire: Pointer;
    function TryAcquire(out aPtr: Pointer): Boolean;
    procedure Release(aPtr: Pointer);
    procedure Reset;
    function BlockSize: SizeUInt;
    function Capacity: SizeUInt;
    function Available: SizeUInt;
    function InUse: SizeUInt;
    function AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
    procedure ReleaseN(const aPtrs: array of Pointer; aCount: Integer);

    property Pool: IMemPool read FPool;
  end;

  TBlockPoolToMemPoolAdapter = class(TInterfacedObject, IMemPool)
  private
    FPool: IBlockPool;
  public
    constructor Create(aPool: IBlockPool);
    function Alloc: Pointer;
    function TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean;
    procedure Free(APtr: Pointer);
    procedure Reset;
    function GetBlockSize: SizeUInt;
    function GetCapacity: Integer;
    function GetAllocatedCount: Integer;

    property Pool: IBlockPool read FPool;
  end;

  TStackPoolToArenaAdapter = class(TInterfacedObject, IArena)
  private
    FPool: IStackPool;
  public
    constructor Create(aPool: IStackPool);
    function Alloc(const aLayout: TMemLayout): TAllocResult;
    function AllocZeroed(const aLayout: TMemLayout): TAllocResult;
    function SaveMark: TArenaMarker;
    procedure RestoreToMark(aMark: TArenaMarker);
    procedure Reset;
    function TotalSize: SizeUInt;
    function UsedSize: SizeUInt;
    function RemainingSize: SizeUInt;

    property Pool: IStackPool read FPool;
  end;

  TArenaToStackPoolAdapter = class(TInterfacedObject, IStackPool)
  private
    FArena: IArena;
  public
    constructor Create(aArena: IArena);
    function Alloc(ASize: SizeUInt; AAlignment: SizeUInt = SizeOf(Pointer)): Pointer;
    function TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean;
    procedure Reset;
    procedure RestoreState(AOffset: SizeUInt);
    function GetTotalSize: SizeUInt;
    function GetOffset: SizeUInt;

    property Arena: IArena read FArena;
  end;

function WrapAsBlockPool(aPool: IMemPool): IBlockPool;
function WrapAsMemPool(aPool: IBlockPool): IMemPool;
function WrapAsArena(aPool: IStackPool): IArena;
function WrapAsStackPool(aArena: IArena): IStackPool;

implementation

function WrapAsBlockPool(aPool: IMemPool): IBlockPool;
begin
  Result := TMemPoolToBlockPoolAdapter.Create(aPool);
end;

function WrapAsMemPool(aPool: IBlockPool): IMemPool;
begin
  Result := TBlockPoolToMemPoolAdapter.Create(aPool);
end;

function WrapAsArena(aPool: IStackPool): IArena;
begin
  Result := TStackPoolToArenaAdapter.Create(aPool);
end;

function WrapAsStackPool(aArena: IArena): IStackPool;
begin
  Result := TArenaToStackPoolAdapter.Create(aArena);
end;

constructor TMemPoolAdapter.Create(aPool: TMemPool);
begin
  inherited Create;
  if aPool = nil then
    raise ENullReferenceError.Create('TMemPoolAdapter.Create: aPool is nil');
  FPool := aPool;
end;

function TMemPoolAdapter.Alloc: Pointer;
begin
  Result := FPool.Alloc;
end;

function TMemPoolAdapter.TryAlloc(out aPtr: Pointer; aSize: SizeUInt): Boolean;
begin
  if (aSize <> 0) and (aSize > FPool.BlockSize) then
  begin
    aPtr := nil;
    Exit(False);
  end;
  Result := FPool.TryAlloc(aPtr);
end;

procedure TMemPoolAdapter.Free(aPtr: Pointer);
begin
  FPool.ReleasePtr(aPtr);
end;

procedure TMemPoolAdapter.Reset;
begin
  FPool.Reset;
end;

function TMemPoolAdapter.GetBlockSize: SizeUInt;
begin
  Result := FPool.BlockSize;
end;

function TMemPoolAdapter.GetCapacity: Integer;
begin
  Result := FPool.Capacity;
end;

function TMemPoolAdapter.GetAllocatedCount: Integer;
begin
  Result := FPool.AllocatedCount;
end;

constructor TStackPoolAdapter.Create(aPool: TStackPool);
begin
  inherited Create;
  if aPool = nil then
    raise ENullReferenceError.Create('TStackPoolAdapter.Create: aPool is nil');
  FPool := aPool;
end;

function TStackPoolAdapter.Alloc(aSize: SizeUInt; aAlignment: SizeUInt): Pointer;
begin
  Result := FPool.Alloc(aSize, aAlignment);
end;

function TStackPoolAdapter.TryAlloc(out aPtr: Pointer; aSize: SizeUInt): Boolean;
begin
  Result := FPool.TryAlloc(aSize, aPtr, SizeOf(Pointer));
end;

procedure TStackPoolAdapter.Reset;
begin
  FPool.Reset;
end;

procedure TStackPoolAdapter.RestoreState(aOffset: SizeUInt);
begin
  FPool.RestoreState(aOffset);
end;

function TStackPoolAdapter.GetTotalSize: SizeUInt;
begin
  Result := FPool.TotalSize;
end;

function TStackPoolAdapter.GetOffset: SizeUInt;
begin
  Result := FPool.UsedSize;
end;

constructor TSlabPoolAdapter.Create(aPool: TSlabPool);
begin
  inherited Create;
  if aPool = nil then
    raise ENullReferenceError.Create('TSlabPoolAdapter.Create: aPool is nil');
  FPool := aPool;
end;

function TSlabPoolAdapter.Alloc(aSize: SizeUInt): Pointer;
begin
  Result := FPool.GetMem(aSize);
end;

function TSlabPoolAdapter.TryAlloc(out aPtr: Pointer; aSize: SizeUInt): Boolean;
begin
  aPtr := FPool.GetMem(aSize);
  Result := aPtr <> nil;
end;

procedure TSlabPoolAdapter.Free(aPtr: Pointer);
begin
  FPool.FreeMem(aPtr);
end;

procedure TSlabPoolAdapter.Reset;
begin
  FPool.Reset;
end;

constructor TMemPoolToBlockPoolAdapter.Create(aPool: IMemPool);
begin
  inherited Create;
  FPool := aPool;
end;

function TMemPoolToBlockPoolAdapter.Acquire: Pointer;
begin
  Result := FPool.Alloc;
end;

function TMemPoolToBlockPoolAdapter.TryAcquire(out aPtr: Pointer): Boolean;
begin
  Result := FPool.TryAlloc(aPtr, FPool.GetBlockSize);
end;

function TMemPoolToBlockPoolAdapter.AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
var
  LIdx: Integer;
  LPtr: Pointer;
begin
  Result := 0;
  if aCount <= 0 then
    Exit(0);
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aPtrs) then
      Break;
    LPtr := Acquire;
    if LPtr = nil then
      Break;
    aPtrs[LIdx] := LPtr;
    Inc(Result);
  end;
end;

procedure TMemPoolToBlockPoolAdapter.ReleaseN(const aPtrs: array of Pointer; aCount: Integer);
var
  LIdx: Integer;
begin
  if aCount <= 0 then
    Exit;
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aPtrs) then
      Break;
    Release(aPtrs[LIdx]);
  end;
end;

procedure TMemPoolToBlockPoolAdapter.Release(aPtr: Pointer);
begin
  FPool.Free(aPtr);
end;

procedure TMemPoolToBlockPoolAdapter.Reset;
begin
  FPool.Reset;
end;

function TMemPoolToBlockPoolAdapter.BlockSize: SizeUInt;
begin
  Result := FPool.GetBlockSize;
end;

function TMemPoolToBlockPoolAdapter.Capacity: SizeUInt;
begin
  Result := SizeUInt(FPool.GetCapacity);
end;

function TMemPoolToBlockPoolAdapter.Available: SizeUInt;
begin
  Result := SizeUInt(FPool.GetCapacity - FPool.GetAllocatedCount);
end;

function TMemPoolToBlockPoolAdapter.InUse: SizeUInt;
begin
  Result := SizeUInt(FPool.GetAllocatedCount);
end;

constructor TBlockPoolToMemPoolAdapter.Create(aPool: IBlockPool);
begin
  inherited Create;
  FPool := aPool;
end;

function TBlockPoolToMemPoolAdapter.Alloc: Pointer;
begin
  Result := FPool.Acquire;
end;

function TBlockPoolToMemPoolAdapter.TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean;
begin
  Result := FPool.TryAcquire(APtr);
end;

procedure TBlockPoolToMemPoolAdapter.Free(APtr: Pointer);
begin
  FPool.Release(APtr);
end;

procedure TBlockPoolToMemPoolAdapter.Reset;
begin
  FPool.Reset;
end;

function TBlockPoolToMemPoolAdapter.GetBlockSize: SizeUInt;
begin
  Result := FPool.BlockSize;
end;

function TBlockPoolToMemPoolAdapter.GetCapacity: Integer;
begin
  Result := Integer(FPool.Capacity);
end;

function TBlockPoolToMemPoolAdapter.GetAllocatedCount: Integer;
begin
  Result := Integer(FPool.InUse);
end;

constructor TStackPoolToArenaAdapter.Create(aPool: IStackPool);
begin
  inherited Create;
  FPool := aPool;
end;

function TStackPoolToArenaAdapter.Alloc(const aLayout: TMemLayout): TAllocResult;
var
  LPtr: Pointer;
begin
  if not aLayout.IsValid then
    Exit(TAllocResult.Err(aeInvalidLayout));
  if aLayout.IsZeroSized then
    Exit(TAllocResult.Ok(nil));

  LPtr := FPool.Alloc(aLayout.Size, aLayout.Align);
  if LPtr = nil then
    Result := TAllocResult.Err(aeOutOfMemory)
  else
    Result := TAllocResult.Ok(LPtr);
end;

function TStackPoolToArenaAdapter.AllocZeroed(const aLayout: TMemLayout): TAllocResult;
begin
  Result := Alloc(aLayout);
  if Result.IsOk and (Result.Ptr <> nil) then
    FillChar(Result.Ptr^, aLayout.Size, 0);
end;

function TStackPoolToArenaAdapter.SaveMark: TArenaMarker;
begin
  Result := TArenaMarker(FPool.GetOffset);
end;

procedure TStackPoolToArenaAdapter.RestoreToMark(aMark: TArenaMarker);
begin
  FPool.RestoreState(SizeUInt(aMark));
end;

procedure TStackPoolToArenaAdapter.Reset;
begin
  FPool.Reset;
end;

function TStackPoolToArenaAdapter.TotalSize: SizeUInt;
begin
  Result := FPool.GetTotalSize;
end;

function TStackPoolToArenaAdapter.UsedSize: SizeUInt;
begin
  Result := FPool.GetOffset;
end;

function TStackPoolToArenaAdapter.RemainingSize: SizeUInt;
begin
  Result := FPool.GetTotalSize - FPool.GetOffset;
end;

constructor TArenaToStackPoolAdapter.Create(aArena: IArena);
begin
  inherited Create;
  FArena := aArena;
end;

function TArenaToStackPoolAdapter.Alloc(ASize: SizeUInt; AAlignment: SizeUInt): Pointer;
var
  LLayout: TMemLayout;
  LResult: TAllocResult;
begin
  LLayout := TMemLayout.Create(ASize, AAlignment);
  LResult := FArena.Alloc(LLayout);
  Result := LResult.Unwrap;
end;

function TArenaToStackPoolAdapter.TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean;
var
  LLayout: TMemLayout;
  LResult: TAllocResult;
begin
  LLayout := TMemLayout.Create(ASize, SizeOf(Pointer));
  LResult := FArena.Alloc(LLayout);
  APtr := LResult.Unwrap;
  Result := LResult.IsOk;
end;

procedure TArenaToStackPoolAdapter.Reset;
begin
  FArena.Reset;
end;

procedure TArenaToStackPoolAdapter.RestoreState(AOffset: SizeUInt);
begin
  FArena.RestoreToMark(TArenaMarker(AOffset));
end;

function TArenaToStackPoolAdapter.GetTotalSize: SizeUInt;
begin
  Result := FArena.TotalSize;
end;

function TArenaToStackPoolAdapter.GetOffset: SizeUInt;
begin
  Result := FArena.UsedSize;
end;

end.
