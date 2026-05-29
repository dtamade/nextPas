unit nextpas.core.fs.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.fs.base;

type
  IFile = interface(IStream)
    ['{A1B2C3D4-E5F6-7890-ABCD-200000000001}']
    function Name: string;
    function Stat: TFileInfo;
    procedure Sync;
    procedure Truncate(const ASize: Int64);
  end;

  IDirIterator = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-200000000002}']
    function Next: Boolean;
    function Entry: TDirEntry;
    procedure Close;
  end;

implementation

end.
