{
```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# nextpas.core.mem.pool.adapter - 池接口适配器
## Abstract 摘要

Adapter classes to bridge v1.x pool interfaces (IMemPool, IStackPool) with
v2.0 pool interfaces (IBlockPool, IArena).
适配器类，用于桥接 v1.x 池接口与 v2.0 池接口。

## Declaration 声明

Author:    fafafaStudio
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.pool.adapter;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.interfaces,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.layout,
  nextpas.core.mem.error;

type
  {**
   * TMemPoolToBlockPoolAdapter
   *
   * @desc 将 IMemPool (v1.x) 适配为 IBlockPool (v2.0)
   *       Adapts IMemPool (v1.x) to IBlockPool (v2.0)
   *
   * @example
   *   var OldPool: IMemPool := TMemPool.Create(64, 100);
   *   var NewPool: IBlockPool := TMemPoolToBlockPoolAdapter.Create(OldPool);
   *}
  TMemPoolToBlockPoolAdapter = class(TInterfacedObject, IBlockPool, IBlockPoolBatch)
  private
    FPool: IMemPool;
  public
    constructor Create(aPool: IMemPool);

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

    property Pool: IMemPool read FPool;
  end;

  {**
   * TBlockPoolToMemPoolAdapter
   *
   * @desc 将 IBlockPool (v2.0) 适配为 IMemPool (v1.x)
   *       Adapts IBlockPool (v2.0) to IMemPool (v1.x)
   *
   * @example
   *   var NewPool: IBlockPool := TBlockPool.Create(64, 100);
   *   var OldPool: IMemPool := TBlockPoolToMemPoolAdapter.Create(NewPool);
   *}
  TBlockPoolToMemPoolAdapter = class(TInterfacedObject, IMemPool)
  private
    FPool: IBlockPool;
  public
    constructor Create(aPool: IBlockPool);

    { IMemPool }
    function Alloc: Pointer;
    function TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean;
    procedure Free(APtr: Pointer);
    procedure Reset;
    function GetBlockSize: SizeUInt;
    function GetCapacity: Integer;
    function GetAllocatedCount: Integer;

    property Pool: IBlockPool read FPool;
  end;

  {**
   * TStackPoolToArenaAdapter
   *
   * @desc 将 IStackPool (v1.x) 适配为 IArena (v2.0)
   *       Adapts IStackPool (v1.x) to IArena (v2.0)
   *
   * @example
   *   var OldPool: IStackPool := TStackPool.Create(64 * 1024);
   *   var NewArena: IArena := TStackPoolToArenaAdapter.Create(OldPool);
   *}
  TStackPoolToArenaAdapter = class(TInterfacedObject, IArena)
  private
    FPool: IStackPool;
  public
    constructor Create(aPool: IStackPool);

    { IArena }
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

  {**
   * TArenaToStackPoolAdapter
   *
   * @desc 将 IArena (v2.0) 适配为 IStackPool (v1.x)
   *       Adapts IArena (v2.0) to IStackPool (v1.x)
   *
   * @example
   *   var NewArena: IArena := TArena.Create(64 * 1024);
   *   var OldPool: IStackPool := TArenaToStackPoolAdapter.Create(NewArena);
   *}
  TArenaToStackPoolAdapter = class(TInterfacedObject, IStackPool)
  private
    FArena: IArena;
  public
    constructor Create(aArena: IArena);

    { IStackPool }
    function Alloc(ASize: SizeUInt; AAlignment: SizeUInt = SizeOf(Pointer)): Pointer;
    function TryAlloc(out APtr: Pointer; ASize: SizeUInt): Boolean;
    procedure Reset;
    procedure RestoreState(AOffset: SizeUInt);
    function GetTotalSize: SizeUInt;
    function GetOffset: SizeUInt;

    property Arena: IArena read FArena;
  end;

{** 便捷函数 *}

function WrapAsBlockPool(aPool: IMemPool): IBlockPool;
function WrapAsMemPool(aPool: IBlockPool): IMemPool;
function WrapAsArena(aPool: IStackPool): IArena;
function WrapAsStackPool(aArena: IArena): IStackPool;

implementation

{ Convenience functions }

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

{ TMemPoolToBlockPoolAdapter }

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
  if aCount <= 0 then Exit(0);
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
  if aCount <= 0 then Exit;
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

{ TBlockPoolToMemPoolAdapter }

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
  // v1.x TryAlloc 忽略 ASize（必须 <= BlockSize）
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

{ TStackPoolToArenaAdapter }

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
  begin
    Result := TAllocResult.Err(aeInvalidLayout);
    Exit;
  end;

  if aLayout.IsZeroSized then
  begin
    Result := TAllocResult.Ok(nil);
    Exit;
  end;

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

{ TArenaToStackPoolAdapter }

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
