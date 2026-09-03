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

  { EAudioSpatialError - 3D 空间化参数非法（listener/spatial params 越界） }
  EAudioSpatialError = class(EAudioError);

  { EAudioBusError - 总线格式非法/总线不存在/混音失败 }
  EAudioBusError = class(EAudioError);

  { EAudioBankError - Bank 名称冲突/Id 非法/容量超限 }
  EAudioBankError = class(EAudioError);

  { EAudioResourceError - 资源异步加载失败/去重冲突/Probe 失败 }
  EAudioResourceError = class(EAudioError);

  { EAudioPlaylistError - 播放列表格式失配/队列非法 }
  EAudioPlaylistError = class(EAudioError);

  { EAudioEventError - 事件系统参数/实例非法 }
  EAudioEventError = class(EAudioError);

  { EAudioStudioError - 工程/自动化/音序器参数非法 }
  EAudioStudioError = class(EAudioError);

  { EAudioCodecError - 通用编解码失败（flac/mp3/vorbis 过渡桩复用，避免借用 EAudioDeviceError 跨域） }
  EAudioCodecError = class(EAudioDecodeError);

implementation

end.
