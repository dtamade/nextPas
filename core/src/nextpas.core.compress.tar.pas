unit nextpas.core.compress.tar;
{** @deprecated 薄转发：Tar 已晋升为独立 L2 模块 nextpas.core.tar。
    本单元仅保留兼容 re-export，新增代码请 uses nextpas.core.tar。 *}

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
