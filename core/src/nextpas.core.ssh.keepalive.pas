unit nextpas.core.ssh.keepalive;

{** nextpas.core.ssh.keepalive - KeepAlive 策略兼容门面。
 *
 *  已抽离至 `nextpas.core.net.maintenance.keepalive`（L1，`TInstant` 单调时钟，
 *  `IntervalMs<=0` 禁用）。本单元为 ssh 兼容薄门面，纯 re-export + inline
 *  零成本 alias，零 `SysUtils` 直连。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.maintenance.keepalive;

type
  TKeepAlivePolicy = nextpas.core.net.maintenance.keepalive.TKeepAlivePolicy;

implementation

end.
