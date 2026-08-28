unit nextpas.core.sevenz.limits;

{**
 * nextpas.core.sevenz.limits - 7z 炸弹与头部硬上限纯常量
 *
 * 集中管理所有解码期硬上限，reader / writer / bench / test 共享同一
 * 常量源，避免两处硬编码漂移。纯常量单元，不依赖 intf 的接口声明。
 *}

{$I nextpas.core.settings.inc}

interface

const
  { 单次解压默认上限：防御头部谎报尺寸导致的分配炸弹 }
  SEVENZ_DEFAULT_MAX_OUTPUT = UInt64(8) * 1024 * 1024 * 1024;
  { 头部字节上限：NextHeaderSize 超此阈值视为炸弹头（64 MiB 远超正常 header） }
  SEVENZ_MAX_HEADER_SIZE = UInt64(64) * 1024 * 1024;
  { 单条 pack 流上限：单流即超 64 MiB 视为炸弹 }
  SEVENZ_MAX_PACK_SIZE = UInt64(64) * 1024 * 1024;
  { 条目数上限：防御头部谎报 NumFiles }
  SEVENZ_MAX_FILE_COUNT = 1000000;
  { 单条目名 UTF-16LE 字节上限（含终止符前）：64 KiB }
  SEVENZ_MAX_NAME_BYTES = 64 * 1024;
  { 流式窗口大小（读端 ExtractTo 与写端 Move+CRC 共用） }
  SEVENZ_EXTRACT_WINDOW = 256 * 1024;
  SEVENZ_WRITER_CHUNK   = 64 * 1024;
  { 头部结构数量上限 }
  SEVENZ_MAX_PACK_STREAMS = 1000000;
  SEVENZ_MAX_FOLDERS      = 1000000;
  SEVENZ_MAX_CODER_PROPS  = 1 * 1024 * 1024;
  { 解压输出与编码属性复用上限（与 DEFAULT_MAX_OUTPUT 同源，消除魔法数） }
  SEVENZ_MAX_UNPACK_SIZE  = SEVENZ_DEFAULT_MAX_OUTPUT;
  SEVENZ_MAX_CRC_COUNT    = SEVENZ_MAX_FILE_COUNT;

implementation

end.
