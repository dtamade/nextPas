unit nextpas.core.db.pool.intf;

{** @desc db.pool 接口契约（base ← intf 分层，CONTRACT §2.7）。
       定义连接工厂闭包、归还句柄能力与池核心态接口。
       零逻辑；实现侧由 nextpas.core.db.pool.core 提供。
       性能：接口引用计数为原子操作，无锁快速路径。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.pool.base;

type
  { 连接工厂闭包：后端特化唯一入口 }
  TDbConnectFunc = reference to function: IDbConnection;

  {** 归还句柄能力（池代理实现）：捕获数据库错误后调用 Discard 弃置
      当前底层连接，释放引用时不回池而直接关闭。 *}
  IDbPooledHandle = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE006}']
    procedure Discard;
  end;

  {** 池核心态接口：引用计数所有权的载体。每个在途代理持强引用，
      核心态存活到最后一个代理归还；门面提前 Free 时由代理侧自然
      排空。（内部扩展缝：门面只是薄壳，核心态可独立驱动） *}
  IDbPoolCore = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE007}']
    function AcquireRead: IDbConnection;
    function AcquireWriter: IDbConnection;
    procedure Shutdown;
    function Policy: TDbPoolPolicy;
    procedure ReturnProxy(AProxy: TObject);
    { 安全点冲刷：扫描到期租约并入账，随后在锁外触发已积压报告。
      只允许在非析构链上下文调用（见单元头注泄漏检测条目）。 }
    procedure FlushDiagnostics;
    { 单源 scoped-lease 路由（facade 零逻辑薄转发→ impl 体外联，零额外分配，try..finally 置 nil 归还，零 I-Cache 膨胀） }
    procedure ScopedLease(const ABody: TDbConnProc; const AIsWriter: Boolean);
  end;

implementation

end.
