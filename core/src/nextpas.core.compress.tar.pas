unit nextpas.core.compress.tar;
{** @deprecated 薄转发：Tar 已晋升为独立 L2 模块 nextpas.core.tar。
    本单元仅保留兼容 re-export，新增代码请 uses nextpas.core.tar。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
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

end.
