unit nextpas.core.ssh.keepalive.scheduler;

{** nextpas.core.ssh.keepalive.scheduler - KeepAlive 调度器兼容门面。
 *
 *  已抽离至 `nextpas.core.net.maintenance.scheduler`（L2，`TAsyncLoop`
 *  周期调度 + `TKeepAlivePolicy` 单源）。本单元为 ssh 兼容薄门面，
 *  纯 re-export + inline 零成本 alias，复用于 TLS/QUIC 定时心跳。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.maintenance.scheduler;

type
  TKeepAliveScheduler = nextpas.core.net.maintenance.scheduler.TKeepAliveScheduler;

implementation

end.
