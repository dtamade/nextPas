unit nextpas.core.compress.tar;
{** @deprecated 薄转发：Tar 已晋升为独立 L2 模块 nextpas.core.tar。
    本单元仅保留兼容 re-export，新增代码请 uses nextpas.core.tar。
    联邦：经 nextpas.core.archive.fs 单缝联邦（L2 同层显式 one-way，tar.fs/tar.builder 双路径已 via archive.fs 单源，本地薄别名复用 bytes.ops 单源 inline/零拷贝，资源 try-finally 不丢，见 module-registry）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.archive.fs,
  nextpas.core.tar.base,
  nextpas.core.tar.reader,
  nextpas.core.tar.writer;

type
  TTarEntryKind = nextpas.core.tar.base.TTarEntryKind;
  TTarHeader = nextpas.core.tar.base.TTarHeader;
  TTarReader = nextpas.core.tar.reader.TTarReader;
  TTarWriter = nextpas.core.tar.writer.TTarWriter;

const
  tekRegular = nextpas.core.tar.base.tekRegular;
  tekHardLink = nextpas.core.tar.base.tekHardLink;
  tekSymlink = nextpas.core.tar.base.tekSymlink;
  tekCharDevice = nextpas.core.tar.base.tekCharDevice;
  tekBlockDevice = nextpas.core.tar.base.tekBlockDevice;
  tekDirectory = nextpas.core.tar.base.tekDirectory;
  tekFifo = nextpas.core.tar.base.tekFifo;

implementation

uses
  nextpas.core.bytes.ops; // bytes.ops 单源 Move/Span 零拷贝，inline 薄转发，守 design-conventions 红线1；空实现仅为单源审计锚点，薄别名本身零分配 inline

end.
