{
# nextpas.core.mem.allocator.cow

## 摘要

Copy-on-Write 分配器 — 共享内存，写时复制。

特性:
- 多个引用共享同一块内存，节省内存
- 写入时自动复制（通过引用计数检测）
- 适用于快照、事务回滚、只读数据共享

适用场景：配置快照、事务系统、只读数据共享。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.cow;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  {** 最大 CoW 引用数 }
  COW_MAX_REFS = 256;

type
  {** CoW 引用记录 }
  TCowRef = record
    OriginalPtr: Pointer;   { 原始指针 }
    DataPtr: Pointer;       { 数据指针（可能共享） }
    DataSize: SizeUInt;     { 数据大小 }
    RefCount: Integer;      { 引用计数 }
    IsShared: Boolean;      { 是否共享 }
  end;

  {** CoW 统计信息 }
  TCowStats = record
    TotalAllocs: UInt64;     { 总分配次数 }
    SharedAllocs: UInt64;    { 共享分配次数 }
    CopiedOnWrite: UInt64;   { 写时复制次数 }
    ActiveRefs: Integer;     { 活跃引用数 }
    SharedBytes: UInt64;     { 共享字节数 }
  end;

  {** TCowAllocator
   *
   *  Copy-on-Write 分配器。
   *  多个引用共享同一块内存，写入时自动复制。
   *
   *  使用模式:
   *    1. Alloc 获取原始指针
   *    2. Share 创建共享引用
   *    3. 写入共享引用时自动复制（通过 WriteNotify）
   *    4. Free 释放引用
   *}
  TCowAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    { 引用表 }
    FRefs: array[0..COW_MAX_REFS - 1] of TCowRef;
    FActiveRefCount: Integer;
    { 统计 }
    FTotalAllocs: UInt64;
    FSharedAllocs: UInt64;
    FCopiedOnWrite: UInt64;
    function FindRef(APtr: Pointer): Integer;
  public
    {** 创建 CoW 分配器 }
    constructor Create(AInner: IAllocator);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;

    {** 创建共享引用（返回新指针，与原始共享数据） }
    function Share(APtr: Pointer): Pointer;
    {** 通知写入（如果共享则复制，返回可写指针） }
    function WriteNotify(APtr: Pointer): Pointer;
    {** 获取统计信息 }
    function GetStats: TCowStats;
    {** 是否为共享引用 }
    function IsShared(APtr: Pointer): Boolean;

    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.mem.error;

{ --- TCowAllocator --- }

constructor TCowAllocator.Create(AInner: IAllocator);
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TCowAllocator.Create: AInner cannot be nil');
  FInner := AInner;
  FActiveRefCount := 0;
  FTotalAllocs := 0;
  FSharedAllocs := 0;
  FCopiedOnWrite := 0;
  FillChar(FRefs, SizeOf(FRefs), 0);
end;

destructor TCowAllocator.Destroy;
var
  LI: Integer;
begin
  { 释放所有活跃引用的数据 }
  for LI := 0 to COW_MAX_REFS - 1 do
  begin
    if FRefs[LI].OriginalPtr <> nil then
    begin
      if not FRefs[LI].IsShared then
        FInner.FreeMem(FRefs[LI].DataPtr);
      FRefs[LI].OriginalPtr := nil;
      FRefs[LI].DataPtr := nil;
    end;
  end;
  FInner := nil;
  inherited Destroy;
end;

function TCowAllocator.FindRef(APtr: Pointer): Integer;
var
  LI: Integer;
begin
  for LI := 0 to COW_MAX_REFS - 1 do
  begin
    if FRefs[LI].OriginalPtr = APtr then
      Exit(LI);
  end;
  Result := -1;
end;

function TCowAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LI: Integer;
begin
  { 查找空闲槽位 }
  LI := 0;
  while (LI < COW_MAX_REFS) and (FRefs[LI].OriginalPtr <> nil) do
    Inc(LI);
  if LI >= COW_MAX_REFS then
    raise EAllocError.Create(aeOutOfMemory, 'TCowAllocator.GetMem: too many refs');

  { 从内部分配器分配数据 }
  FRefs[LI].DataPtr := FInner.GetMem(ASize);
  if FRefs[LI].DataPtr = nil then
    Exit(nil);

  FRefs[LI].DataSize := ASize;
  FRefs[LI].RefCount := 1;
  FRefs[LI].IsShared := False;

  { 原始指针 = 数据指针（首次分配） }
  FRefs[LI].OriginalPtr := FRefs[LI].DataPtr;
  Result := FRefs[LI].OriginalPtr;

  Inc(FActiveRefCount);
  Inc(FTotalAllocs);
end;

function TCowAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TCowAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LIdx: Integer;
begin
  if ASize = 0 then begin FreeMem(APtr); Exit(nil); end;
  if APtr = nil then
    Exit(GetMem(ASize));

  LIdx := FindRef(APtr);
  if LIdx < 0 then
    raise EAllocError.Create(aeInvalidPointer, 'TCowAllocator.ReallocMem: unknown pointer');

  { 分配新块，复制数据 }
  Result := GetMem(ASize);
  if Result <> nil then
  begin
    if FRefs[FindRef(Result)].DataSize < FRefs[LIdx].DataSize then
      Move(FRefs[LIdx].DataPtr^, Result^, FRefs[FindRef(Result)].DataSize)
    else
      Move(FRefs[LIdx].DataPtr^, Result^, FRefs[LIdx].DataSize);
    FreeMem(APtr);
  end;
end;

procedure TCowAllocator.FreeMem(APtr: Pointer); inline;
var
  LIdx: Integer;
begin
  if APtr = nil then Exit;

  LIdx := FindRef(APtr);
  if LIdx < 0 then Exit;

  Dec(FRefs[LIdx].RefCount);
  if FRefs[LIdx].RefCount <= 0 then
  begin
    { 最后一个引用，释放数据 }
    if not FRefs[LIdx].IsShared then
      FInner.FreeMem(FRefs[LIdx].DataPtr);
    FRefs[LIdx].OriginalPtr := nil;
    FRefs[LIdx].DataPtr := nil;
    FRefs[LIdx].DataSize := 0;
    Dec(FActiveRefCount);
  end;
end;

function TCowAllocator.Share(APtr: Pointer): Pointer;
var
  LIdx, LNewIdx: Integer;
begin
  LIdx := FindRef(APtr);
  if LIdx < 0 then
    raise EAllocError.Create(aeInvalidPointer, 'TCowAllocator.Share: unknown pointer');

  { 查找空闲槽位 }
  LNewIdx := 0;
  while (LNewIdx < COW_MAX_REFS) and (FRefs[LNewIdx].OriginalPtr <> nil) do
    Inc(LNewIdx);
  if LNewIdx >= COW_MAX_REFS then
    raise EAllocError.Create(aeOutOfMemory, 'TCowAllocator.Share: too many refs');

  { 创建共享引用 }
  FRefs[LNewIdx].DataPtr := FRefs[LIdx].DataPtr;
  FRefs[LNewIdx].DataSize := FRefs[LIdx].DataSize;
  FRefs[LNewIdx].RefCount := 1;
  FRefs[LNewIdx].IsShared := True;
  FRefs[LNewIdx].OriginalPtr := FRefs[LIdx].DataPtr;

  { 标记原始引用为共享 }
  FRefs[LIdx].IsShared := True;
  Inc(FRefs[LIdx].RefCount);

  Result := FRefs[LNewIdx].OriginalPtr;
  Inc(FActiveRefCount);
  Inc(FSharedAllocs);
end;

function TCowAllocator.WriteNotify(APtr: Pointer): Pointer;
var
  LIdx: Integer;
  LNewData: Pointer;
begin
  LIdx := FindRef(APtr);
  if LIdx < 0 then
    raise EAllocError.Create(aeInvalidPointer, 'TCowAllocator.WriteNotify: unknown pointer');

  if not FRefs[LIdx].IsShared then
    Exit(FRefs[LIdx].DataPtr);

  { 共享状态，需要复制 }
  LNewData := FInner.GetMem(FRefs[LIdx].DataSize);
  if LNewData = nil then
    raise EAllocError.Create(aeOutOfMemory, 'TCowAllocator.WriteNotify: copy failed');

  Move(FRefs[LIdx].DataPtr^, LNewData^, FRefs[LIdx].DataSize);
  FRefs[LIdx].DataPtr := LNewData;
  FRefs[LIdx].IsShared := False;
  FRefs[LIdx].OriginalPtr := LNewData;

  Inc(FCopiedOnWrite);
  Result := LNewData;
end;

function TCowAllocator.GetStats: TCowStats;
var
  LI: Integer;
begin
  Result.TotalAllocs := FTotalAllocs;
  Result.SharedAllocs := FSharedAllocs;
  Result.CopiedOnWrite := FCopiedOnWrite;
  Result.ActiveRefs := FActiveRefCount;
  Result.SharedBytes := 0;
  for LI := 0 to COW_MAX_REFS - 1 do
  begin
    if (FRefs[LI].OriginalPtr <> nil) and FRefs[LI].IsShared then
      Inc(Result.SharedBytes, UInt64(FRefs[LI].DataSize));
  end;
end;

function TCowAllocator.IsShared(APtr: Pointer): Boolean;
var
  LIdx: Integer;
begin
  LIdx := FindRef(APtr);
  Result := (LIdx >= 0) and FRefs[LIdx].IsShared;
end;

function TCowAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

end.
