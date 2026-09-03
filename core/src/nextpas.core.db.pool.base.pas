unit nextpas.core.db.pool.base;

{** @desc db.pool 基础类型（L2 基础设施通用池，CONTRACT §2.7 单真源；L2 下沉后 wallet L3 仅 L0-L2 单向复用，无同层耦合）。
       纯数据载体：策略记录、泄漏报告通道与数组别名。
       不依赖同模块 intf/impl，base ← intf ← impl ← facade 分层根。
       复用 bytes.ops 单源（若需串/字节转换经 StringToBytes/BytesToString
       单 Move 零拷贝，不自建副本）；性能冷热分明 inline 证据见 intf/facade。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.log.intf;

type
  { 泄漏报告通道（V3-C3）：nil = 经 LeakLogger（nil→NullLogger 零IO）路由，核心池零直接 StdErr。回调在池调用线程同步
    执行，实现内不得再进本池（死锁自担）。 }
  TDbPoolLeakEvent = reference to procedure(const AReport: string);

  { 单次检查点收集到的泄漏报告串集 }
  TDbPoolLeakReports = array of string;

  TDbPoolPolicy = record
    MaxReadConnections: Integer;   { 读连接硬上限 }
    AcquireTimeoutMs: Integer;     { >0 耗尽排队等待；=0 立即抛 }
    ValidateOnAcquire: Boolean;    { 取出前 SELECT 1 探活 }
    MaxLifetimeSec: Integer;       { 连接最长寿命（建连起算）；0 = 不限 }
    IdleTimeoutSec: Integer;       { 空闲超时回收；0 = 不限 }
    MinConnections: Integer;       { 预热下限（Create 即建满） }
    { ---- V3-C3 HikariCP 三招（尾部追加，纯增量）---- }
    { 泄漏检测阈值：租约持有超过阈值后在检查点扫描入账（Warned 一次），
      报告于安全点冲刷；0 = 关，默认 60000ms（60s）开以避免裸 Acquire/Writer
      忘归还或闭包捕获滞留读/写槽位时静默死锁（显式置 0 可关以压 bench 噪声）。
      诚实模型：无看门狗线程——发现依赖下一次池活动或显式 FlushDiagnostics；
      检测到 ≠ 回收，租约所有权仍归持有者。 }
    LeakDetectionThresholdMs: Integer;
    { 报告通道：nil = 经 LeakLogger 路由（见下）。回调在池调用线程同步执行，
      实现内不得再进本池（死锁自担）。 }
    OnLeakDetected: TDbPoolLeakEvent;
    { 日志抽象：OnLeakDetected 为 nil 时的优雅路由（L0 ILogger），nil→NullLogger 零直接IO，核心池零 StdErr 副作用 }
    LeakLogger: ILogger;
    { 获取栈采样（debug 开关）：Acquire 捕获 ≤16 帧原始代码地址，
      泄漏报告附带作定位线索；默认 False 零成本。地址行经
      BackTraceStrFunc 格式化，符号解析取决于链接器调试信息。 }
    DebugAcquireStack: Boolean;
    class function CreateDefault: TDbPoolPolicy; static; inline;
    class function Default: TDbPoolPolicy; static; inline; deprecated 'Use CreateDefault - avoids collision with System.Default intrinsic';
  end;

implementation

uses
  nextpas.core.bytes.ops;

  { 编译期单源门禁：串/字节零拷贝单源为 bytes.ops（BYTES_OPS_SINGLE_SOURCE），漂移编译期拦截 }


class function TDbPoolPolicy.CreateDefault: TDbPoolPolicy; inline;
begin
  { 逐字段显式赋值，托管字段（闭包/接口）显式置 nil 更直白；inline 薄转发零 I-Cache 膨胀 }
  Result.MaxReadConnections := 4;
  Result.AcquireTimeoutMs := 5000;
  Result.ValidateOnAcquire := False;
  Result.MaxLifetimeSec := 0;
  Result.IdleTimeoutSec := 60;
  Result.MinConnections := 0;
  { V3-C3：泄漏检测默认 60s 开——裸 Acquire 忘归还/闭包捕获滞留时经 Warned+LeakLogger 及时暴露，避免池死锁静默；bench/离线可显式置 0 关 }
  Result.LeakDetectionThresholdMs := 60000;
  Result.OnLeakDetected := nil;
  Result.LeakLogger := nil;
  Result.DebugAcquireStack := False;
end;

class function TDbPoolPolicy.Default: TDbPoolPolicy; inline;
begin
  Result := CreateDefault;
end;

end.
