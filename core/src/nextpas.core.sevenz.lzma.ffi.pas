unit nextpas.core.sevenz.lzma.ffi;

{**
 * nextpas.core.sevenz.lzma.ffi - liblzma ABI 缝（纯声明）
 *
 * 仅含 ABI 常量、结构与 cdecl 函数指针类型；零逻辑零加载。
 * 动态探测与解码实现位于 nextpas.core.sevenz.lzma.ffi.decoder。
 *}

{$I nextpas.core.settings.inc}

interface

const
  LIBLZMA_SO_NAMES: array[0..2] of AnsiString = (
    'liblzma.so.5',
    'liblzma.so',
    'liblzma.so.1'
  );
  LIBLZMA_PROBE_SYMBOL = 'lzma_raw_buffer_decode';

const
  { xz 过滤器 ID }
  LZMA_FILTER_LZMA1 = UInt64($4000000000000001);
  { 扩展 LZMA1：解码端需给定精确解压尺寸；7z 的 LZMA1 流通常无 EOS，须走此路径 }
  LZMA_FILTER_LZMA1EXT = UInt64($4000000000000002);
  LZMA_FILTER_LZMA2 = UInt64($21);

  LZMA_OK = 0;
  LZMA_STREAM_END = 1;
  { 过滤器选项不被支持（含旧库不认识 LZMA_FILTER_LZMA1EXT 的情形） }
  LZMA_OPTIONS_ERROR = 8;
  { 输入耗尽且无 EOS、输出未满时返回：容器自带精确尺寸，属正常收尾 }
  LZMA_BUF_ERROR = 10;

  { 允许流中带 EOPM 结束标记（7z 中罕见但合法） }
  LZMA_LZMA1EXT_ALLOW_EOPM = UInt32($01);

type
  { lzma_options_lzma 覆盖层：解码仅依赖前段字段；
    结构体按上游尺寸放大并整体清零，保证 ABI 兼容
    （ext_* 为 liblzma ≥5.3 的 LZMA_FILTER_LZMA1EXT 所需） }
  PLzmaOptions = ^TLzmaOptions;
  TLzmaOptions = record
    DictSize: UInt32;          { offset 0 }
    ReservedPad: UInt32;       { 对齐填充 }
    PresetDict: Pointer;       { offset 8 }
    PresetDictSize: UInt32;    { offset 16 }
    Lc: UInt32;                { offset 20 }
    Lp: UInt32;                { offset 24 }
    Pb: UInt32;                { offset 28 }
    Mode: UInt32;              { offset 32 }
    NiceLen: UInt32;           { offset 36 }
    MatchFinder: UInt32;       { offset 40 }
    Depth: UInt32;             { offset 44 }
    ExtFlags: UInt32;          { offset 48：LZMA_LZMA1EXT_ALLOW_EOPM 等 }
    ExtSizeLow: UInt32;        { offset 52：精确解压尺寸低 32 位 }
    ExtSizeHigh: UInt32;       { offset 56：高 32 位 }
    ReservedTail: array[0..12] of UInt32;
  end;

  TLzmaFilter = record
    Id: UInt64;
    Options: Pointer;
  end;
  PLzmaFilter = ^TLzmaFilter;

  TLzmaRawBufferDecode = function(AFilters: PLzmaFilter;
    AAllocator: Pointer; const AIn: PByte; var AInPos: SizeUInt;
    AInSize: SizeUInt; AOut: PByte; var AOutPos: SizeUInt;
    AOutSize: SizeUInt): Integer; cdecl;

implementation

end.
