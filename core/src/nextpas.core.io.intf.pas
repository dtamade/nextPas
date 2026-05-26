unit nextpas.core.io.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.base;

type
  IReader = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000001}']
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

  IWriter = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000002}']
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

  ISeeker = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000003}']
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
  end;

  ICloser = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000004}']
    procedure Close;
  end;

  IFlusher = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000005}']
    procedure Flush;
  end;

  IStream = interface(IReader)
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000006}']
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    property Size: Int64 read GetSize;
    property Position: Int64 read GetPosition write SetPosition;
  end;

implementation

end.
