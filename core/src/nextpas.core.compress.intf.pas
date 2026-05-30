unit nextpas.core.compress.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf;

type
  ICompressWriter = interface(IWriter)
    ['{D1E2F3A4-B5C6-7890-ABCD-400000000001}']
    procedure Flush;
    procedure Close;
  end;

  IDecompressReader = interface(IReader)
    ['{D1E2F3A4-B5C6-7890-ABCD-400000000002}']
    procedure Close;
  end;

implementation

end.
