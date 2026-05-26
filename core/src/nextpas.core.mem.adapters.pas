unit nextpas.core.mem.adapters;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.mem.interfaces,
  nextpas.core.mem.mem_pool,
  nextpas.core.mem.stack_pool,
  nextpas.core.mem.pool.slab;

type
  {**
   * TMemPoolAdapter
   *
   * @desc 将类 TMemPool 适配为接口 IMemPool（v1.x 兼容层）
   *}
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

  {**
   * TStackPoolAdapter
   *
   * @desc 将类 TStackPool 适配为接口 IStackPool（v1.x 兼容层）
   *}
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

  {**
   * TSlabPoolAdapter
   *
   * @desc 将类 TSlabPool 适配为接口 ISlabPool（v1.x 兼容层）
   *}
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

implementation

{ TMemPoolAdapter }

constructor TMemPoolAdapter.Create(aPool: TMemPool);
begin
  inherited Create;
  if aPool = nil then
    raise EArgumentNilException.Create('TMemPoolAdapter.Create: aPool is nil');
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

{ TStackPoolAdapter }

constructor TStackPoolAdapter.Create(aPool: TStackPool);
begin
  inherited Create;
  if aPool = nil then
    raise EArgumentNilException.Create('TStackPoolAdapter.Create: aPool is nil');
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

{ TSlabPoolAdapter }

constructor TSlabPoolAdapter.Create(aPool: TSlabPool);
begin
  inherited Create;
  if aPool = nil then
    raise EArgumentNilException.Create('TSlabPoolAdapter.Create: aPool is nil');
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

end.
