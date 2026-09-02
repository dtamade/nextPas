unit nextpas.core.sevenz.limits deprecated 'use nextpas.core.sevenz.base - single source for SEVENZ_MAX_*';

{**
 * nextpas.core.sevenz.limits - 兼容别名（已弃用）
 *
 * 单源已收敛至 nextpas.core.sevenz.base，本单元仅保留历史路径的 deprecated 转发，
 * 新代码应直接 uses nextpas.core.sevenz.base。13 个阈值常量不再作为第二公共源；
 * 本单元不新增逻辑，reader/writer/header 已改用 base，避免 API 面碎片化。
 * 性能：const 别名零拷贝、编译期常量折叠，无运行时开销；inline/zero-copy 证据与 base 一致。
 * 稳定性：无资源分配，转发无泄漏风险；历史路径保留以保障 CONTRACT 兼容。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sevenz.base;

const
  SEVENZ_DEFAULT_MAX_OUTPUT = nextpas.core.sevenz.base.SEVENZ_DEFAULT_MAX_OUTPUT deprecated 'use nextpas.core.sevenz.base.SEVENZ_DEFAULT_MAX_OUTPUT';
  SEVENZ_MAX_HEADER_SIZE = nextpas.core.sevenz.base.SEVENZ_MAX_HEADER_SIZE deprecated 'use nextpas.core.sevenz.base.SEVENZ_MAX_HEADER_SIZE';
  SEVENZ_MAX_PACK_SIZE = nextpas.core.sevenz.base.SEVENZ_MAX_PACK_SIZE deprecated 'use nextpas.core.sevenz.base.SEVENZ_MAX_PACK_SIZE';
  SEVENZ_MAX_FILE_COUNT = nextpas.core.sevenz.base.SEVENZ_MAX_FILE_COUNT deprecated 'use nextpas.core.sevenz.base.SEVENZ_MAX_FILE_COUNT';
  SEVENZ_MAX_NAME_BYTES = nextpas.core.sevenz.base.SEVENZ_MAX_NAME_BYTES deprecated 'use nextpas.core.sevenz.base.SEVENZ_MAX_NAME_BYTES';
  SEVENZ_EXTRACT_WINDOW = nextpas.core.sevenz.base.SEVENZ_EXTRACT_WINDOW deprecated 'use nextpas.core.sevenz.base.SEVENZ_EXTRACT_WINDOW';
  SEVENZ_WRITER_CHUNK   = nextpas.core.sevenz.base.SEVENZ_WRITER_CHUNK deprecated 'use nextpas.core.sevenz.base.SEVENZ_WRITER_CHUNK';
  SEVENZ_MAX_PACK_STREAMS = nextpas.core.sevenz.base.SEVENZ_MAX_PACK_STREAMS deprecated 'use nextpas.core.sevenz.base.SEVENZ_MAX_PACK_STREAMS';
  SEVENZ_MAX_FOLDERS      = nextpas.core.sevenz.base.SEVENZ_MAX_FOLDERS deprecated 'use nextpas.core.sevenz.base.SEVENZ_MAX_FOLDERS';
  SEVENZ_MAX_CODER_PROPS  = nextpas.core.sevenz.base.SEVENZ_MAX_CODER_PROPS deprecated 'use nextpas.core.sevenz.base.SEVENZ_MAX_CODER_PROPS';
  SEVENZ_MAX_UNPACK_SIZE  = nextpas.core.sevenz.base.SEVENZ_MAX_UNPACK_SIZE deprecated 'use nextpas.core.sevenz.base.SEVENZ_MAX_UNPACK_SIZE';
  SEVENZ_MAX_CRC_COUNT    = nextpas.core.sevenz.base.SEVENZ_MAX_CRC_COUNT deprecated 'use nextpas.core.sevenz.base.SEVENZ_MAX_CRC_COUNT';
  SEVENZ_CACHE_MAX_BYTES = nextpas.core.sevenz.base.SEVENZ_CACHE_MAX_BYTES deprecated 'use nextpas.core.sevenz.base.SEVENZ_CACHE_MAX_BYTES';

implementation

end.
