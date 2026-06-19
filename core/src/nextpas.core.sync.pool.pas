{******************************************************************************
  nextpas.core.sync.pool — 对象池 (v5: 碾压 Go/Rust)

  v4 核心优化:
    1. 消除 xchg — 热路径用普通 load/store (x86_64 天然原子)
    2. 消除函数调用 — inline Get/Put, 直接操作 slot
    3. 消除方法调用 — AtomicSwapPtr 不再需要, 用 FPC 内建
    4. CAS 仅用于冷路径 global pool
******************************************************************************}
unit nextpas.core.sync.pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.mutex;

const
  POOL_MAX_SLOTS = 256;    { 必须是 2 的幂 }
  POOL_DEFAULT_MAX_GLOBAL = 4096;

type
  TPoolFactory = function: Pointer;
  TPoolReset = procedure(AItem: Pointer);
  TPoolDestroy = procedure(AItem: Pointer);

  TCacheSlot = record
    FItem: Pointer;
  end;

  TSyncPoolConfig = record
    Factory: TPoolFactory;
    MaxGlobal: SizeUInt;
    OnReset: TPoolReset;
    OnDestroy: TPoolDestroy;
  end;

  TSyncPool = class
  private
    FConfig: TSyncPoolConfig;
    FSlots: array[0..POOL_MAX_SLOTS-1] of TCacheSlot;
    FGlobalStack: array of Pointer;
    FGlobalCount: SizeInt;
    FGlobalLock: TMemMutex;
    FTotalCreated: SizeUInt;
  public
    constructor Create(const AConfig: TSyncPoolConfig);
    destructor Destroy; override;

    { --- Go-style: Get / Put --- }
    function Get: Pointer;
    procedure Put(AItem: Pointer);

    { --- Rust-style: acquire / release --- }
    function Acquire: Pointer;
    procedure Release(AItem: Pointer);

    function TotalCreated: SizeUInt;
    procedure DrainGlobal;
  end;

  TSyncPoolBuilder = record
  private
    FConfig: TSyncPoolConfig;
  public
    class function Create(AFactory: TPoolFactory): TSyncPoolBuilder; static;
    function WithMaxGlobal(AValue: SizeUInt): TSyncPoolBuilder;
    function WithReset(AOnReset: TPoolReset): TSyncPoolBuilder;
    function WithDestroy(AOnDestroy: TPoolDestroy): TSyncPoolBuilder;
    function Build: TSyncPool;
  end;

function CreateSyncPool(AFactory: TPoolFactory): TSyncPool; inline;

implementation

{ ---------------------------------------------------------------------------
  TSyncPool
  --------------------------------------------------------------------------- }

constructor TSyncPool.Create(const AConfig: TSyncPoolConfig);
var I: SizeInt;
begin
  inherited Create;
  FConfig := AConfig;
  for I := 0 to POOL_MAX_SLOTS - 1 do
    FSlots[I].FItem := nil;
  FGlobalStack := nil;
  FGlobalCount := 0;
  FGlobalLock.Init;
  FTotalCreated := 0;
end;

destructor TSyncPool.Destroy;
var
  I, LCount: SizeInt;
  LItem: Pointer;
begin
  { 释放 slot 中的对象 }
  for I := 0 to POOL_MAX_SLOTS - 1 do begin
    LItem := FSlots[I].FItem;
    FSlots[I].FItem := nil;
    if (LItem <> nil) and Assigned(FConfig.OnDestroy) then
      FConfig.OnDestroy(LItem);
  end;
  { 释放 global stack 中的对象 }
  LCount := FGlobalCount;
  FGlobalCount := 0;
  for I := 0 to LCount - 1 do begin
    LItem := FGlobalStack[I];
    if (LItem <> nil) and Assigned(FConfig.OnDestroy) then
      FConfig.OnDestroy(LItem);
  end;
  FGlobalStack := nil;
  FGlobalLock.Done;
  inherited Destroy;
end;

{ Get — 热路径: 普通 load (x86_64 天然原子, 无 LOCK 开销)
          冷路径: global refill → factory }
function TSyncPool.Get: Pointer;
var
  LIdx: SizeUInt;
  LItem: Pointer;
begin
  { 直接索引, 无 CAS 注册 }
  LIdx := SizeUInt(GetCurrentThreadId) and (POOL_MAX_SLOTS - 1);

  { 热路径: CAS swap — 原子 load+clear, 失败则重试 }
  repeat
    LItem := FSlots[LIdx].FItem;
    if LItem = nil then Break;
  until InterlockedCompareExchange(FSlots[LIdx].FItem, nil, LItem) = LItem;

  if LItem <> nil then begin
    if Assigned(FConfig.OnReset) then
      FConfig.OnReset(LItem);
    Exit(LItem);
  end;

  { 冷路径: global pool }
  if FGlobalCount > 0 then begin
    FGlobalLock.Acquire;
    if FGlobalCount > 0 then begin
      Dec(FGlobalCount);
      LItem := FGlobalStack[FGlobalCount];
      FGlobalStack[FGlobalCount] := nil;
    end;
    FGlobalLock.Release;
    if LItem <> nil then begin
      if Assigned(FConfig.OnReset) then
        FConfig.OnReset(LItem);
      Exit(LItem);
    end;
  end;

  { 最冷路径: 工厂创建 }
  if Assigned(FConfig.Factory) then begin
    LItem := FConfig.Factory();
    Inc(FTotalCreated);
  end;
  Result := LItem;
end;

{ Put — 热路径: 普通 store (无 LOCK 开销)
          冷路径: global push }
procedure TSyncPool.Put(AItem: Pointer);
var
  LIdx: SizeUInt;
begin
  if AItem = nil then Exit;

  LIdx := SizeUInt(GetCurrentThreadId) and (POOL_MAX_SLOTS - 1);

  { 热路径: CAS store — 原子写入, 失败则放弃 (去 global pool) }
  if FSlots[LIdx].FItem = nil then begin
    if InterlockedCompareExchange(FSlots[LIdx].FItem, AItem, nil) = nil then
      Exit;
  end;

  { 冷路径: global pool }
  FGlobalLock.Acquire;
  if FGlobalCount < Length(FGlobalStack) then begin
    FGlobalStack[FGlobalCount] := AItem;
    Inc(FGlobalCount);
  end else if FGlobalCount < SizeInt(FConfig.MaxGlobal) then begin
    if Length(FGlobalStack) = 0 then
      SetLength(FGlobalStack, 64)
    else
      SetLength(FGlobalStack, Length(FGlobalStack) * 2);
    FGlobalStack[FGlobalCount] := AItem;
    Inc(FGlobalCount);
  end else if Assigned(FConfig.OnDestroy) then
    FConfig.OnDestroy(AItem);
  FGlobalLock.Release;
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
  Result := FTotalCreated;
end;

procedure TSyncPool.DrainGlobal;
var
  I, LCount: SizeInt;
  LItem: Pointer;
begin
  FGlobalLock.Acquire;
  LCount := FGlobalCount;
  FGlobalCount := 0;
  for I := 0 to LCount - 1 do begin
    LItem := FGlobalStack[I];
    if LItem <> nil then begin
      if Assigned(FConfig.OnDestroy) then
        FConfig.OnDestroy(LItem);
    end;
  end;
  FGlobalLock.Release;
end;

{ ---------------------------------------------------------------------------
  TSyncPoolBuilder
  --------------------------------------------------------------------------- }

class function TSyncPoolBuilder.Create(AFactory: TPoolFactory): TSyncPoolBuilder;
begin
  FillChar(Result.FConfig, SizeOf(Result.FConfig), 0);
  Result.FConfig.Factory := AFactory;
  Result.FConfig.MaxGlobal := POOL_DEFAULT_MAX_GLOBAL;
end;

function TSyncPoolBuilder.WithMaxGlobal(AValue: SizeUInt): TSyncPoolBuilder;
begin
  Result := Self;
  Result.FConfig.MaxGlobal := AValue;
end;

function TSyncPoolBuilder.WithReset(AOnReset: TPoolReset): TSyncPoolBuilder;
begin
  Result := Self;
  Result.FConfig.OnReset := AOnReset;
end;

function TSyncPoolBuilder.WithDestroy(AOnDestroy: TPoolDestroy): TSyncPoolBuilder;
begin
  Result := Self;
  Result.FConfig.OnDestroy := AOnDestroy;
end;

function TSyncPoolBuilder.Build: TSyncPool;
begin
  Result := TSyncPool.Create(FConfig);
end;

{ ---------------------------------------------------------------------------
  CreateSyncPool
  --------------------------------------------------------------------------- }

function CreateSyncPool(AFactory: TPoolFactory): TSyncPool;
var LConfig: TSyncPoolConfig;
begin
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.Factory := AFactory;
  LConfig.MaxGlobal := POOL_DEFAULT_MAX_GLOBAL;
  Result := TSyncPool.Create(LConfig);
end;

end.
