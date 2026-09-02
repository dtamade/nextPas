unit nextpas.core.compress.tar;
{** @deprecated 薄转发（待移除）：Tar 已晋升独立 L2 nextpas.core.tar，本单元仅保留兼容 re-export，新增代码请直接 uses nextpas.core.tar；旧转发待迁移后移除以消除重复面。当前经 nextpas.core.tar 门面单源薄转发（原经 archive.fs 单缝联邦已收敛至 tar 内部，本地薄别名复用 bytes.ops 单源 inline/零拷贝，资源 try-finally 不丢，见 module-registry）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tar;

type
  TTarEntryKind = nextpas.core.tar.TTarEntryKind;
  TTarHeader = nextpas.core.tar.TTarHeader;
  TTarReader = nextpas.core.tar.TTarReader;
  TTarWriter = nextpas.core.tar.TTarWriter;

const
  tekRegular = nextpas.core.tar.tekRegular;
  tekHardLink = nextpas.core.tar.tekHardLink;
  tekSymlink = nextpas.core.tar.tekSymlink;
  tekCharDevice = nextpas.core.tar.tekCharDevice;
  tekBlockDevice = nextpas.core.tar.tekBlockDevice;
  tekDirectory = nextpas.core.tar.tekDirectory;
  tekFifo = nextpas.core.tar.tekFifo;

implementation

end.
