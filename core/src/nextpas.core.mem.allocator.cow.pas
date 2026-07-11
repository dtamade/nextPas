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
  {** CoW 引用记录（每个引用有唯一标识符）
   *
   *  Key:      查找键。原始引用 = 数据指针，共享引用 = 哨兵指针。
   *  DataPtr:  数据指针。WriteNotify 后可能指向新副本。
   *  IsShared: 是否为共享引用。
   *}
  TCowRef = record
    Key: Pointer;           { 查找键（原始 = 数据指针，共享 = 哨兵指针） }
    DataPtr: Pointer;       { 数据指针 }
    DataSize: SizeUInt;     { 数据大小 }
    IsShared: Boolean;      { 是否为共享引用 }
  end;

  {** 数据引用计数记录 }
  TCowDataRef = record
    DataPtr: Pointer;       { 数据指针 }
    RefCount: Integer;      { 引用计数（原始 + 共享引用总数） }
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
   *  设计要点:
   *    - 原始引用：Key = 数据指针，通过 FindRef 查找
   *    - 共享引用：Key = 哨兵指针（从 FInner 分配的小块内存），通过 FindRef 查找
   *    - 数据引用计数：独立跟踪每个数据块的引用总数
   *    - FreeMem：原始引用递减数据引用计数；共享引用释放哨兵并递减
   *    - WriteNotify：分配新副本，递减原数据引用计数，创建新的独立引用
   *}
  TCowAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    { 引用表：每个引用有唯一 Key }
    FRefs: array[0..COW_MAX_REFS - 1] of TCowRef;
    { 数据引用计数表：跟踪每个数据块的引用总数 }
    FDataRefs: array[0..COW_MAX_REFS - 1] of TCowDataRef;
    FActiveRefCount: Integer;
    { 统计 }
    FTotalAllocs: UInt64;
    FSharedAllocs: UInt64;
    FCopiedOnWrite: UInt64;
    function FindRef(AKey: Pointer): Integer;
    function FindDataRef(ADataPtr: Pointer): Integer;
    procedure IncDataRef(ADataPtr: Pointer);
    procedure DecDataRef(ADataPtr: Pointer);
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
  FillChar(FDataRefs, SizeOf(FDataRefs), 0);
end;

destructor TCowAllocator.Destroy;
var
  LI: Integer;
begin
  { 释放所有活跃引用的数据 }
  for LI := 0 to COW_MAX_REFS - 1 do
  begin
    if FRefs[LI].Key <> nil then
    begin
      if FRefs[LI].IsShared then
        FInner.FreeMem(FRefs[LI].Key)  { 释放哨兵指针 }
      else
        FInner.FreeMem(FRefs[LI].DataPtr);  { 释放数据 }
      FRefs[LI].Key := nil;
      FRefs[LI].DataPtr := nil;
    end;
  end;
  FInner := nil;
  inherited Destroy;
end;

function TCowAllocator.FindRef(AKey: Pointer): Integer;
var
  LI: Integer;
begin
  for LI := 0 to COW_MAX_REFS - 1 do
  begin
    if FRefs[LI].Key = AKey then
      Exit(LI);
  end;
  Result := -1;
end;

function TCowAllocator.FindDataRef(ADataPtr: Pointer): Integer;
var
  LI: Integer;
begin
  for LI := 0 to COW_MAX_REFS - 1 do
  begin
    if FDataRefs[LI].DataPtr = ADataPtr then
      Exit(LI);
  end;
  Result := -1;
end;

procedure TCowAllocator.IncDataRef(ADataPtr: Pointer);
var
  LI: Integer;
begin
  LI := FindDataRef(ADataPtr);
  if LI >= 0 then
    Inc(FDataRefs[LI].RefCount)
  else
  begin
    { 新数据，查找空闲槽位 }
    LI := 0;
    while (LI < COW_MAX_REFS) and (FDataRefs[LI].DataPtr <> nil) do
      Inc(LI);
    if LI >= COW_MAX_REFS then
      raise EAllocError.Create(aeOutOfMemory, 'TCowAllocator.IncDataRef: too many data refs');
    FDataRefs[LI].DataPtr := ADataPtr;
    FDataRefs[LI].RefCount := 1;
  end;
end;

procedure TCowAllocator.DecDataRef(ADataPtr: Pointer);
var
  LI: Integer;
begin
  LI := FindDataRef(ADataPtr);
  if LI < 0 then Exit;
  Dec(FDataRefs[LI].RefCount);
  if FDataRefs[LI].RefCount <= 0 then
  begin
    FInner.FreeMem(ADataPtr);
    FDataRefs[LI].DataPtr := nil;
    FDataRefs[LI].RefCount := 0;
  end;
end;

function TCowAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LI: Integer;
begin
  { 查找空闲槽位 }
  LI := 0;
  while (LI < COW_MAX_REFS) and (FRefs[LI].Key <> nil) do
    Inc(LI);
  if LI >= COW_MAX_REFS then
    raise EAllocError.Create(aeOutOfMemory, 'TCowAllocator.GetMem: too many refs');

  { 从内部分配器分配数据 }
  FRefs[LI].DataPtr := FInner.GetMem(ASize);
  if FRefs[LI].DataPtr = nil then
    Exit(nil);

  FRefs[LI].DataSize := ASize;
  FRefs[LI].IsShared := False;
  FRefs[LI].Key := FRefs[LI].DataPtr;

  { 初始化数据引用计数 }
  IncDataRef(FRefs[LI].DataPtr);

  Result := FRefs[LI].Key;
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
  LKey: Pointer;
begin
  if APtr = nil then Exit;

  LIdx := FindRef(APtr);
  if LIdx < 0 then Exit;

  LKey := FRefs[LIdx].Key;

  if FRefs[LIdx].IsShared then
  begin
    { 共享引用：释放哨兵指针，递减数据引用计数 }
    DecDataRef(FRefs[LIdx].DataPtr);
    FInner.FreeMem(LKey);
  end
  else
  begin
    { 原始引用或 WriteNotify 后的引用：递减数据引用计数 }
    DecDataRef(FRefs[LIdx].DataPtr);
    { 如果 Key 是哨兵指针（Share 分配的），也需要释放 }
    if LKey <> FRefs[LIdx].DataPtr then
      FInner.FreeMem(LKey);
  end;
  FRefs[LIdx].Key := nil;
  FRefs[LIdx].DataPtr := nil;
  FRefs[LIdx].DataSize := 0;
  Dec(FActiveRefCount);
end;

function TCowAllocator.Share(APtr: Pointer): Pointer;
var
  LIdx, LNewIdx: Integer;
  LSentinel: PPointer;
begin
  LIdx := FindRef(APtr);
  if LIdx < 0 then
    raise EAllocError.Create(aeInvalidPointer, 'TCowAllocator.Share: unknown pointer');

  { 查找空闲槽位 }
  LNewIdx := 0;
  while (LNewIdx < COW_MAX_REFS) and (FRefs[LNewIdx].Key <> nil) do
    Inc(LNewIdx);
  if LNewIdx >= COW_MAX_REFS then
    raise EAllocError.Create(aeOutOfMemory, 'TCowAllocator.Share: too many refs');

  { 分配哨兵指针作为共享引用的唯一标识 }
  LSentinel := PPointer(FInner.GetMem(SizeOf(Pointer)));
  if LSentinel = nil then
    raise EAllocError.Create(aeOutOfMemory, 'TCowAllocator.Share: sentinel alloc failed');
  LSentinel^ := FRefs[LIdx].DataPtr;

  { 创建共享引用：Key = 哨兵（唯一标识），DataPtr = 共享数据 }
  FRefs[LNewIdx].Key := Pointer(LSentinel);
  FRefs[LNewIdx].DataPtr := FRefs[LIdx].DataPtr;
  FRefs[LNewIdx].DataSize := FRefs[LIdx].DataSize;
  FRefs[LNewIdx].IsShared := True;

  { 标记原始引用为共享 }
  FRefs[LIdx].IsShared := True;

  { 增加数据引用计数 }
  IncDataRef(FRefs[LIdx].DataPtr);

  Result := FRefs[LIdx].DataPtr;
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

  { 递减原数据引用计数，更新为新数据 }
  DecDataRef(FRefs[LIdx].DataPtr);
  FRefs[LIdx].DataPtr := LNewData;
  FRefs[LIdx].IsShared := False;
  { 保留 Key（哨兵指针），供 FreeMem 查找和释放 }
  IncDataRef(LNewData);

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
    if (FRefs[LI].Key <> nil) and FRefs[LI].IsShared then
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
