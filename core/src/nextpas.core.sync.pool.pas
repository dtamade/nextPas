{******************************************************************************
  nextpas.core.sync.pool — 对象池 (v8: per-pool TLS freelist + 预分配)

  架构:
    1. 每线程 TLS 链表节点按 Owner(pool) 隔离 freelist — 多 pool 同线程安全
    2. 预分配 — 批量 Factory, 跳过热路径 Create/Free
    3. 对象池管理生命周期 — Get 不 Create, Put 不 Free
    4. 冷路径: nextpas IMutex 保护 global stack
    5. DrainTLS — 将本 pool 在当前线程的 freelist 归还 global

  线程安全约束:
    - 每线程可为多个 TSyncPool 实例各持一个 TLS 节点
    - Factory 回调可能被多线程并发调用, 调用者须保证其线程安全性
    - FTotalCreated 通过 InterLockedIncrement 原子递增
******************************************************************************}
unit nextpas.core.sync.pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex;

type
  TPoolFactory = function: Pointer;
  TPoolDestroy = procedure(AItem: Pointer);

  { 池化对象基类 — 继承此类获得池化能力 }
  TPoolItem = class
  public
    PoolNext: TPoolItem;
  end;

  TSyncPoolConfig = record
    Factory: TPoolFactory;
    OnDestroy: TPoolDestroy;
    PreAllocCount: SizeUInt; { 预分配对象数, 0 = 不预分配 }
  end;

  TSyncPool = class
  private
    FConfig: TSyncPoolConfig;
    FGlobalHead: TPoolItem;
    FGlobalLock: IMutex;
    FTotalCreated: Integer; { 原子递增 via InterLockedIncrement }
    { 预分配块管理 }
    FPreAllocBlocks: array of Pointer; { 每块 = mmap/GetMem 的大内存 }
    FPreAllocBlockCount: SizeInt;
    procedure InternalPreAlloc(ACount: SizeUInt);
    procedure InternalDrainGlobal;
    function EnsureTlsNode: Pointer;
    function FindTlsNode: Pointer;
  public
    constructor Create(const AConfig: TSyncPoolConfig);
    destructor Destroy; override;

    function Get: Pointer;
    procedure Put(AItem: Pointer);

    { Drain current thread's freelist for this pool back to global.
      Call before thread exit to prevent heaptrc leak reports. }
    procedure DrainTLS;

    function Acquire: Pointer; inline;
    procedure Release(AItem: Pointer); inline;

    function TotalCreated: SizeUInt;
    procedure DrainGlobal;
  end;

  TSyncPoolBuilder = record
  private
    FConfig: TSyncPoolConfig;
  public
    class function Create(AFactory: TPoolFactory): TSyncPoolBuilder; static;
    function WithDestroy(AOnDestroy: TPoolDestroy): TSyncPoolBuilder;
    function WithPreAlloc(ACount: SizeUInt): TSyncPoolBuilder;
    function Build: TSyncPool;
  end;

{ L1 通用 Slab 双池单源（CONTRACT §1.2/§50 已反哺）：短临界仅指针存取 inline 零拷贝，供 webview.gtk.pool 等家族薄转发复用 }
generic function SyncPoolTryAcquire<T>(var APool: array of T; var ACount: Integer; ALock: TMutex): T; inline;
generic function SyncPoolTryRelease<T>(var APool: array of T; var ACount: Integer; ALock: TMutex; const AItem: T): Boolean; inline;

function CreateSyncPool(AFactory: TPoolFactory): TSyncPool; inline;

implementation

uses
  nextpas.core.sync.errors,
  nextpas.core.sync.mutex;

generic function SyncPoolTryAcquire<T>(var APool: array of T; var ACount: Integer; ALock: TMutex): T; inline;
begin
  Result := Default(T);
  if ALock <> nil then ALock.Acquire;
  try
    if ACount > 0 then
    begin
      Dec(ACount);
      Result := APool[ACount];
      APool[ACount] := Default(T);
    end;
  finally
    if ALock <> nil then ALock.Release;
  end;
end;

generic function SyncPoolTryRelease<T>(var APool: array of T; var ACount: Integer; ALock: TMutex; const AItem: T): Boolean; inline;
begin
  // perf: short critical only pointer push <1µs inline 零拷贝，零 SetLength 持锁；突发满时由 caller 经 bytes.ops VecGrow 单源在锁外扩容后重试，零回退 New 堆分配（caller 两阶段短临界，热路径仍 <1µs）
  Result := False;
  if ALock <> nil then ALock.Acquire;
  try
    if ACount < Length(APool) then
    begin
      APool[ACount] := AItem;
      Inc(ACount);
      Result := True;
    end;
  finally
    if ALock <> nil then ALock.Release;
  end;
end;

function RequirePoolItem(AItem: Pointer; const AOp: string): TPoolItem;
begin
  if AItem = nil then
    Exit(nil);
  if not (TObject(AItem) is TPoolItem) then
    SyncRaiseArg('TSyncPool.' + AOp + ': item must be TPoolItem');
  Result := TPoolItem(AItem);
end;

type
  PPoolTlsNode = ^TPoolTlsNode;
  TPoolTlsNode = record
    Owner: Pointer;
    Head: TPoolItem;
    Next: PPoolTlsNode;
  end;

threadvar
  GPoolTlsList: PPoolTlsNode;

{ ---------------------------------------------------------------------------
  TLS helpers — per-thread list keyed by pool instance
  --------------------------------------------------------------------------- }

function TSyncPool.FindTlsNode: Pointer;
var
  LNode: PPoolTlsNode;
begin
  LNode := GPoolTlsList;
  while LNode <> nil do
  begin
    if LNode^.Owner = Pointer(Self) then
      Exit(LNode);
    LNode := LNode^.Next;
  end;
  Result := nil;
end;

function TSyncPool.EnsureTlsNode: Pointer;
var
  LNode: PPoolTlsNode;
begin
  LNode := FindTlsNode;
  if LNode <> nil then
    Exit(LNode);
  New(LNode);
  LNode^.Owner := Pointer(Self);
  LNode^.Head := nil;
  LNode^.Next := GPoolTlsList;
  GPoolTlsList := LNode;
  Result := LNode;
end;

{ ---------------------------------------------------------------------------
  TSyncPool — 预分配
  --------------------------------------------------------------------------- }

procedure TSyncPool.InternalPreAlloc(ACount: SizeUInt);
var
  I: SizeUInt;
  LItem: TPoolItem;
begin
  { 批量调用工厂创建对象, 放入 global stack.
    安全前提: 仅在构造函数中调用, 对象尚未对外暴露, 单线程访问. }
  for I := 1 to ACount do begin
    LItem := RequirePoolItem(FConfig.Factory(), 'Factory');
    if LItem = nil then
      SyncRaiseArg('TSyncPool.Factory: must not return nil');
    LItem.PoolNext := FGlobalHead;
    FGlobalHead := LItem;
    InterLockedIncrement(FTotalCreated);
  end;
end;

{ ---------------------------------------------------------------------------
  TSyncPool
  --------------------------------------------------------------------------- }

constructor TSyncPool.Create(const AConfig: TSyncPoolConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FGlobalHead := nil;
  FGlobalLock := TMutex.Create;
  FTotalCreated := 0;
  FPreAllocBlocks := nil;
  FPreAllocBlockCount := 0;
  if FConfig.PreAllocCount > 0 then
    InternalPreAlloc(FConfig.PreAllocCount);
end;

destructor TSyncPool.Destroy;
begin
  DrainTLS;
  InternalDrainGlobal;
  FGlobalLock := nil;
  inherited Destroy;
end;

function TSyncPool.Get: Pointer;
var
  LNode: PPoolTlsNode;
  LItem: TPoolItem;
begin
  { 热路径: 本 pool 的 TLS freelist }
  LNode := FindTlsNode;
  if LNode <> nil then
  begin
    LItem := LNode^.Head;
    if LItem <> nil then
    begin
      LNode^.Head := LItem.PoolNext;
      LItem.PoolNext := nil;
      Exit(LItem);
    end;
  end;

  { 冷路径: global stack }
  FGlobalLock.Acquire;
  try
    LItem := FGlobalHead;
    if LItem <> nil then
    begin
      FGlobalHead := LItem.PoolNext;
      LItem.PoolNext := nil;
      Exit(LItem);
    end;
  finally
    FGlobalLock.Release;
  end;

  { 最冷路径: 工厂创建 }
  if Assigned(FConfig.Factory) then
  begin
    LItem := RequirePoolItem(FConfig.Factory(), 'Factory');
    if LItem = nil then
      SyncRaiseArg('TSyncPool.Factory: must not return nil');
    LItem.PoolNext := nil;
    InterLockedIncrement(FTotalCreated);
  end;
  Result := LItem;
end;

procedure TSyncPool.Put(AItem: Pointer);
var
  LNode: PPoolTlsNode;
  LItem: TPoolItem;
begin
  if AItem = nil then
    Exit;
  LItem := RequirePoolItem(AItem, 'Put');
  LNode := EnsureTlsNode;
  LItem.PoolNext := LNode^.Head;
  LNode^.Head := LItem;
end;

procedure TSyncPool.DrainTLS;
var
  LPrev, LNode: PPoolTlsNode;
  LItem, LTail: TPoolItem;
begin
  LPrev := nil;
  LNode := GPoolTlsList;
  while LNode <> nil do
  begin
    if LNode^.Owner = Pointer(Self) then
    begin
      LItem := LNode^.Head;
      LNode^.Head := nil;
      { unlink node from thread list }
      if LPrev = nil then
        GPoolTlsList := LNode^.Next
      else
        LPrev^.Next := LNode^.Next;
      Dispose(LNode);

      if LItem <> nil then
      begin
        LTail := LItem;
        while LTail.PoolNext <> nil do
          LTail := LTail.PoolNext;
        FGlobalLock.Acquire;
        try
          LTail.PoolNext := FGlobalHead;
          FGlobalHead := LItem;
        finally
          FGlobalLock.Release;
        end;
      end;
      Exit;
    end;
    LPrev := LNode;
    LNode := LNode^.Next;
  end;
end;

function TSyncPool.Acquire: Pointer;
begin
  Result := Get;
end;

procedure TSyncPool.Release(AItem: Pointer);
begin
  Put(AItem);
end;

function TSyncPool.TotalCreated: SizeUInt;
begin
  Result := SizeUInt(FTotalCreated);
end;

procedure TSyncPool.InternalDrainGlobal;
var
  L, N: TPoolItem;
begin
  L := FGlobalHead;
  FGlobalHead := nil;
  while L <> nil do
  begin
    N := L.PoolNext;
    if Assigned(FConfig.OnDestroy) then
      FConfig.OnDestroy(L)
    else
      L.Free;
    L := N;
  end;
end;

procedure TSyncPool.DrainGlobal;
begin
  FGlobalLock.Acquire;
  try
    InternalDrainGlobal;
  finally
    FGlobalLock.Release;
  end;
end;

{ ---------------------------------------------------------------------------
  TSyncPoolBuilder
  --------------------------------------------------------------------------- }

class function TSyncPoolBuilder.Create(AFactory: TPoolFactory): TSyncPoolBuilder;
begin
  FillChar(Result.FConfig, SizeOf(Result.FConfig), 0);
  Result.FConfig.Factory := AFactory;
end;

function TSyncPoolBuilder.WithDestroy(AOnDestroy: TPoolDestroy): TSyncPoolBuilder;
begin
  Result := Self;
  Result.FConfig.OnDestroy := AOnDestroy;
end;

function TSyncPoolBuilder.WithPreAlloc(ACount: SizeUInt): TSyncPoolBuilder;
begin
  Result := Self;
  Result.FConfig.PreAllocCount := ACount;
end;

function TSyncPoolBuilder.Build: TSyncPool;
begin
  Result := TSyncPool.Create(FConfig);
end;

function CreateSyncPool(AFactory: TPoolFactory): TSyncPool;
var
  LConfig: TSyncPoolConfig;
begin
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.Factory := AFactory;
  Result := TSyncPool.Create(LConfig);
end;

end.
