unit nextpas.core.sevenz.limits;

{**
 * nextpas.core.sevenz.limits - 7z 炸弹与头部硬上限纯常量
 *
 * 薄封装：单源在 nextpas.core.sevenz.base，历史路径通过别名保持兼容，
 * reader / writer / header / test 复用同一常量源，避免硬编码漂移。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sevenz.base;

const
  SEVENZ_DEFAULT_MAX_OUTPUT = nextpas.core.sevenz.base.SEVENZ_DEFAULT_MAX_OUTPUT;
  SEVENZ_MAX_HEADER_SIZE = nextpas.core.sevenz.base.SEVENZ_MAX_HEADER_SIZE;
  SEVENZ_MAX_PACK_SIZE = nextpas.core.sevenz.base.SEVENZ_MAX_PACK_SIZE;
  SEVENZ_MAX_FILE_COUNT = nextpas.core.sevenz.base.SEVENZ_MAX_FILE_COUNT;
  SEVENZ_MAX_NAME_BYTES = nextpas.core.sevenz.base.SEVENZ_MAX_NAME_BYTES;
  SEVENZ_EXTRACT_WINDOW = nextpas.core.sevenz.base.SEVENZ_EXTRACT_WINDOW;
  SEVENZ_WRITER_CHUNK   = nextpas.core.sevenz.base.SEVENZ_WRITER_CHUNK;
  SEVENZ_MAX_PACK_STREAMS = nextpas.core.sevenz.base.SEVENZ_MAX_PACK_STREAMS;
  SEVENZ_MAX_FOLDERS      = nextpas.core.sevenz.base.SEVENZ_MAX_FOLDERS;
  SEVENZ_MAX_CODER_PROPS  = nextpas.core.sevenz.base.SEVENZ_MAX_CODER_PROPS;
  SEVENZ_MAX_UNPACK_SIZE  = nextpas.core.sevenz.base.SEVENZ_MAX_UNPACK_SIZE;
  SEVENZ_MAX_CRC_COUNT    = nextpas.core.sevenz.base.SEVENZ_MAX_CRC_COUNT;
  SEVENZ_CACHE_MAX_BYTES = nextpas.core.sevenz.base.SEVENZ_CACHE_MAX_BYTES;
  SEVENZ_AES_MAX_CYCLES_POWER = nextpas.core.sevenz.base.SEVENZ_AES_MAX_CYCLES_POWER;

implementation

end.
