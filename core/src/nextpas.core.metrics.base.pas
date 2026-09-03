unit nextpas.core.metrics.base;

{$I nextpas.core.settings.inc}

interface

const
  { 通用可观测阈值单源：帧/消息 Hard Limit 1 MiB（BRIDGE_PROTOCOL §6）。
    复用 bytes.ops 单源思想（常量即契约，消除魔法数字漂移）；
    L2 通用 metrics Owner 单源，L3 webview.metrics thin-forward alias，
    bench/log 通用可观测与此单源收敛，零重复定义。 }
  METRICS_MAX_FRAME_BYTES = 1 * 1024 * 1024;

implementation

end.
