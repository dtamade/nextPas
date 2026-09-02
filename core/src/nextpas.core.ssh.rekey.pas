unit nextpas.core.ssh.rekey;

{** nextpas.core.ssh.rekey - Rekey 策略兼容门面。
 *
 *  已抽离至 `nextpas.core.net.maintenance.rekey`（L1，`TInstant` 单调时钟，
 *  零 `SysUtils` 直连，消 sync/async 漂移）。本单元为 ssh 兼容薄门面，
 *  纯 re-export + `inline` 零成本 alias，供历史 `TSshRekeyPolicy` 调用方零改动，
 *  新代码应直接 `uses nextpas.core.net.maintenance`。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.maintenance.rekey;

type
  TSshRekeyPolicy = nextpas.core.net.maintenance.rekey.TRekeyPolicy;

implementation

end.
