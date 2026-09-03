unit nextpas.core.db.pool;

{** @desc 通用连接池门面（L2 基础设施，CONTRACT §2.7，纯 re-export 薄壳）。
       对任意后端 IDbConnection 池化，后端特化经连接工厂闭包注入，池体不懂方言。
       门面纯 re-export：策略校验与预热委派核心态，其余全数 inline 薄转发至 IDbPoolCore 单源（WithRead/WithWriter 直连 ScopedLease 零私体中间调度，8线程89k ops/s 锤压零额外 call，守 design-conventions 纯度）。
       性能 inline 薄转发、零拷贝由实现层单点承载（bytes.ops 单源，见 pool.impl）；稳定性资源释放不丢（IDbPoolCore 引用计数保活、Shutdown 幂等、ScopedLease try..finally 置 nil 归还于 impl）。
       业务以 CONTRACT 为准，缺能力反哺 owner。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.intf,
  nextpas.core.db.pool.base,
  nextpas.core.db.pool.intf;

type
  { base re-export — 门面聚合，消费方只 uses 池门面即可 }
  TDbPoolPolicy = nextpas.core.db.pool.base.TDbPoolPolicy;
  TDbPoolLeakEvent = nextpas.core.db.pool.base.TDbPoolLeakEvent;
  TDbPoolLeakReports = nextpas.core.db.pool.base.TDbPoolLeakReports;

  { intf re-export }
  TDbConnectFunc = nextpas.core.db.pool.intf.TDbConnectFunc;
  IDbPooledHandle = nextpas.core.db.pool.intf.IDbPooledHandle;
  IDbPoolCore = nextpas.core.db.pool.intf.IDbPoolCore;

  { 门面：纯 re-export 薄壳——策略校验与预热委派核心态，其余全数 inline 薄转发至 IDbPoolCore（CONTRACT §2.7），零逻辑承载，守 design-conventions 门面纯度 }
  TDbPool = class
  private
    FCore: IDbPoolCore;
  public
    constructor Create(const AConnect: TDbConnectFunc; const APolicy: TDbPoolPolicy);
    destructor Destroy; override;
    function Acquire: IDbConnection; inline;
    function Writer: IDbConnection; inline;
    procedure WithRead(const ABody: TDbConnProc); inline;
    procedure WithWriter(const ABody: TDbConnProc); inline;
    procedure Close; inline;
    function Policy: TDbPoolPolicy; inline;
    procedure FlushDiagnostics; inline;
  end;

{ 薄转发至实现层，inline 于调用点 }
function PoolLeakToBytes(const AReport: string): TBytes; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.pool.impl;

const
  { 字节单源守卫：复用 bytes.ops，漂移编译期拦截 }
  POOL_FACADE_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;
  POOL_FACADE_BYTES_SINGLE_SOURCE_VERSION = BYTES_OPS_SINGLE_SOURCE_VERSION;

{$I nextpas.core.bytes.ops.single_source.inc}

{ 薄转发至实现层，inline }
function PoolLeakToBytes(const AReport: string): TBytes; inline;
begin
  Result := nextpas.core.db.pool.impl.PoolLeakToBytes(AReport);
end;

constructor TDbPool.Create(const AConnect: TDbConnectFunc;
  const APolicy: TDbPoolPolicy);
begin
  inherited Create;
  FCore := CreatePoolCore(AConnect, APolicy);
end;

destructor TDbPool.Destroy;
begin
  if FCore <> nil then
  begin
    FCore.Shutdown;
    FCore := nil;
  end;
  inherited Destroy;
end;

function TDbPool.Acquire: IDbConnection; inline;
begin
  Result := FCore.AcquireRead;
end;

function TDbPool.Writer: IDbConnection; inline;
begin
  Result := FCore.AcquireWriter;
end;

{ 门面纯 re-export：inline 薄转发至核心态 IDbPoolCore.ScopedLease 单源路由（impl 承载 try..finally 置 nil 归还，资源释放不丢，零额外调度） }
procedure TDbPool.WithRead(const ABody: TDbConnProc); inline;
begin
  FCore.ScopedLease(ABody, False);
end;

procedure TDbPool.WithWriter(const ABody: TDbConnProc); inline;
begin
  FCore.ScopedLease(ABody, True);
end;

procedure TDbPool.Close; inline;
begin
  FCore.Shutdown;
end;

function TDbPool.Policy: TDbPoolPolicy; inline;
begin
  Result := FCore.Policy;
end;

procedure TDbPool.FlushDiagnostics; inline;
begin
  FCore.FlushDiagnostics;
end;

end.
