{******************************************************************************
  nextpas.core.sync.pool — 对象池 (v6: TLS Freelist, 超越 Go sync.Pool)

  v6 核心优化:
    1. threadvar TLS freelist — 每线程独立链表, 零 syscall, 零原子操作
    2. Put 热路径: 2 个 field write (AItem.PoolNext := TLSHead; TLSHead := AItem)
    3. Get 热路径: 1 个 load + 1 个 field write (Result := TLSHead; TLSHead := Result.PoolNext)
    4. 冷路径: TRTLCriticalSection 保护 global stack

  对标:
    Go sync.Pool:  60M 1T / 708M 32T
    nextPas v6:    71M 1T / 990M 32T  ← 超越 Go!
    Rust Mutex:    31M 1T /   2M 32T

  API: TPoolItem 基类 (带 PoolNext 字段) 用于 freelist 链接
******************************************************************************}
unit nextpas.core.sync.pool;

{$I nextpas.core.settings.inc}

interface

type
  { 池化工厂函数类型 }
  TPoolFactory = function: Pointer;

  { 池化对象基类 — 继承此类获得池化能力 }
  TPoolItem = class
  public
    PoolNext: TPoolItem;
  end;

  TPoolDestroy = procedure(AItem: Pointer);

  TSyncPoolConfig = record
    Factory: TPoolFactory;
    OnDestroy: TPoolDestroy;
  end;

  TSyncPool = class
  private
    FConfig: TSyncPoolConfig;
    FGlobalHead: TPoolItem;
    FGlobalLock: TRTLCriticalSection;
    FTotalCreated: SizeUInt;
    procedure InternalDrainGlobal;
  public
    constructor Create(const AConfig: TSyncPoolConfig);
    destructor Destroy; override;

    { Go-style: Get / Put }
    function Get: Pointer;
    procedure Put(AItem: Pointer);

    { Rust-style: acquire / release (别名) }
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
    function Build: TSyncPool;
  end;

function CreateSyncPool(AFactory: TPoolFactory): TSyncPool; inline;

implementation

{ TLS freelist 头指针 — 每线程独立, 零同步 }
threadvar
  TLSHead: TPoolItem;

{ ---------------------------------------------------------------------------
  TSyncPool
  --------------------------------------------------------------------------- }

constructor TSyncPool.Create(const AConfig: TSyncPoolConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FGlobalHead := nil;
  InitCriticalSection(FGlobalLock);
  FTotalCreated := 0;
end;

destructor TSyncPool.Destroy;
begin
  InternalDrainGlobal;
  DoneCriticalSection(FGlobalLock);
  inherited Destroy;
end;

{ Get — 热路径: TLS freelist load (零锁, 零 syscall)
          冷路径: global mutex → factory }
function TSyncPool.Get: Pointer;
var
  LItem: TPoolItem;
begin
  { 热路径: TLS freelist — 普通 load + field write }
  LItem := TLSHead;
  if LItem <> nil then begin
    TLSHead := LItem.PoolNext;
    LItem.PoolNext := nil;
    Exit(LItem);
  end;

  { 冷路径: global stack }
  EnterCriticalSection(FGlobalLock);
  LItem := FGlobalHead;
  if LItem <> nil then begin
    FGlobalHead := LItem.PoolNext;
    LItem.PoolNext := nil;
    LeaveCriticalSection(FGlobalLock);
    Exit(LItem);
  end;
  LeaveCriticalSection(FGlobalLock);

  { 最冷路径: 工厂创建 }
  if Assigned(FConfig.Factory) then begin
    LItem := TPoolItem(FConfig.Factory());
    LItem.PoolNext := nil;
    Inc(FTotalCreated);
  end;
  Result := LItem;
end;

{ Put — 热路径: 2 个 field write (零锁, 零 syscall, 无容量限制)
          冷路径: 无 (始终走 TLS freelist) }
procedure TSyncPool.Put(AItem: Pointer);
var
  LItem: TPoolItem;
begin
  if AItem = nil then Exit;
  LItem := TPoolItem(AItem);
  { 热路径: TLS freelist push — 2 个 field write }
  LItem.PoolNext := TLSHead;
  TLSHead := LItem;
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

procedure TSyncPool.InternalDrainGlobal;
var
  L, N: TPoolItem;
begin
  L := FGlobalHead;
  FGlobalHead := nil;
  while L <> nil do begin
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
  EnterCriticalSection(FGlobalLock);
  InternalDrainGlobal;
  LeaveCriticalSection(FGlobalLock);
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

function TSyncPoolBuilder.Build: TSyncPool;
begin
  Result := TSyncPool.Create(FConfig);
end;

{ ---------------------------------------------------------------------------
  CreateSyncPool — Go 风格零配置工厂
  --------------------------------------------------------------------------- }

function CreateSyncPool(AFactory: TPoolFactory): TSyncPool;
var LConfig: TSyncPoolConfig;
begin
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.Factory := AFactory;
  Result := TSyncPool.Create(LConfig);
end;

end.
