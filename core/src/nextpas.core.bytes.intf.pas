unit nextpas.core.bytes.intf;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.bytes.base;

type
  IByteBuffer = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']
    function GetData: PByte;
    function GetSize: SizeUInt;
    function GetCapacity: SizeUInt;
    procedure SetSize(const ASize: SizeUInt);
    function Slice(const AOffset, ALength: SizeUInt): IByteBuffer;
    procedure CopyFrom(const ASrc: PByte; const ACount: SizeUInt);
    property Data: PByte read GetData;
    property Size: SizeUInt read GetSize write SetSize;
    property Capacity: SizeUInt read GetCapacity;
  end;

  IByteBuilder = interface
    ['{D4E5F6A7-B8C9-0123-DEFA-234567890123}']
    function GetSize: SizeUInt;
    procedure AppendByte(const AValue: Byte);
    procedure AppendBytes(const AData: PByte; const ACount: SizeUInt);
    procedure AppendUInt16(const AValue: Word; const AEndian: TEndian);
    procedure AppendUInt32(const AValue: LongWord; const AEndian: TEndian);
    procedure AppendUInt64(const AValue: QWord; const AEndian: TEndian);
    function ToBytes: TBytes;
    procedure Clear;
    property Size: SizeUInt read GetSize;
  end;

implementation

end.
