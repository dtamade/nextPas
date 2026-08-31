unit nextpas.core.audio.errors;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

type
  { EAudioError - 域根，继承 EIOError 与仓库策略对齐 }
  EAudioError = class(EIOError);

  { EAudioDecodeError - 容器/位流损坏、不支持形态 }
  EAudioDecodeError = class(EAudioError);

  { EAudioEncodeError - 编码失败 }
  EAudioEncodeError = class(EAudioError);

  { EAudioDeviceError - 打开/启动失败、协商失败 }
  EAudioDeviceError = class(EAudioError);

  { EAudioGraphError - 成环、类型不匹配、拓扑非法 }
  EAudioGraphError = class(EAudioError);

  { EAudioTimelineError - 时间线/Clip 排布非法 }
  EAudioTimelineError = class(EAudioError);

implementation

end.
