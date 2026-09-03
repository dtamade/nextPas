unit nextpas.core.net.maintenance;

{** nextpas.core.net.maintenance - 通用连接维护门面（L2）。
 *
 *  聚合 Rekey/KeepAlive 策略（L1，`TInstant` 单调时钟，消 sync/async 漂移）
 *  与调度器（L2，`TAsyncLoop` 周期），`bytes.ops` 单源（外层零拷贝由调用方保证）。
 *  供 ssh rekey/keepalive 兼容门面及 tls/quic key phase、http PING 复用。
 *
 *  四件套：`base ← rekey/keepalive ← scheduler ← 门面`，门面纯 re-export，
 *  不含逻辑，消费方 `uses nextpas.core.net.maintenance` 即可。
 *  分层：L2（仅依赖 L0/L1：time + async.loop），不依赖 L3。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.maintenance.base,
  nextpas.core.net.maintenance.rekey,
  nextpas.core.net.maintenance.keepalive,
  nextpas.core.net.maintenance.scheduler;

type
  TRekeyPolicy = nextpas.core.net.maintenance.rekey.TRekeyPolicy;
  TKeepAlivePolicy = nextpas.core.net.maintenance.keepalive.TKeepAlivePolicy;
  TKeepAliveScheduler = nextpas.core.net.maintenance.scheduler.TKeepAliveScheduler;

const
  NET_REKEY_BYTES_DEFAULT = nextpas.core.net.maintenance.base.NET_REKEY_BYTES_DEFAULT;
  NET_REKEY_INTERVAL_MS_DEFAULT = nextpas.core.net.maintenance.base.NET_REKEY_INTERVAL_MS_DEFAULT;
  NET_KEEPALIVE_INTERVAL_MS_DEFAULT = nextpas.core.net.maintenance.base.NET_KEEPALIVE_INTERVAL_MS_DEFAULT;

implementation

end.
