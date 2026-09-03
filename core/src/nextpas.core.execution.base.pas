unit nextpas.core.execution.base;

{$I nextpas.core.settings.inc}

interface

const
  { 异步执行挂载固定税与阈值（L1 单源：owner=execution，L0 纯净；inline 零拷贝，无串/字节分配）
    固定税 ≈ 两次跨线程唤醒（benchmarks.md 15–20µs 实测）；阈值 >2×固定税。
    db.async/http/tui 等高频提交共享此单源阈值，不倒置分层（不依赖 db.base），
    阈值单源=execution.base，bytes.ops 单源。 }
  EXECUTION_MOUNT_OVERHEAD_US = 20; { 两次跨线程唤醒固定税（benchmarks.md 15–20µs 实测） }
  EXECUTION_MIN_WORTHWHILE_US = 50; { 高频微查询阈值：预估 <50µs 不值得异步化（>2×固定税） }

type
  { 单飞执行工作体：在专用线程执行；内部可抛异常由句柄承载 }
  TExecutionWork = reference to procedure;

{** 是否值得异步化：预估耗时 >= 阈值才值得支付固定税。inline 零拷贝。单源=execution.base（L1 纯净，http/tui 共享）。 *}
function ExecutionShouldOffload(const AEstimatedUs: Cardinal): Boolean; inline;

implementation

function ExecutionShouldOffload(const AEstimatedUs: Cardinal): Boolean; inline;
begin
  { inline 单源实现（owner=execution.base，L1 纯净；零拷贝，无串/字节分配，db.async/http/tui 共享复用） }
  Result := AEstimatedUs >= EXECUTION_MIN_WORTHWHILE_US;
end;

end.
