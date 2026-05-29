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

  IReadCloser = interface(IReader)
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000010}']
    procedure Close;
  end;

  IWriteCloser = interface(IWriter)
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000011}']
    procedure Close;
  end;

  IReadWriter = interface(IReader)
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000012}']
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

  IReadWriteCloser = interface(IReader)
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000013}']
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
  end;

  IReaderAt = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000020}']
    function ReadAt(var ABuf; const ACount: SizeUInt; const AOffset: Int64): SizeUInt;
  end;

  IWriterAt = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000021}']
    function WriteAt(const ABuf; const ACount: SizeUInt; const AOffset: Int64): SizeUInt;
  end;

  IByteReader = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000030}']
    function ReadByte: Byte;
  end;

  IByteWriter = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000031}']
    procedure WriteByte(const AValue: Byte);
  end;

  IStringWriter = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000032}']
    function WriteString(const AStr: string): SizeUInt;
  end;

  IReadWriteSeeker = interface(IReader)
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000014}']
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
  end;

  IReaderFrom = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000040}']
    function ReadFrom(const ASrc: IReader): Int64;
  end;

  IWriterTo = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000041}']
    function WriteTo(const ADst: IWriter): Int64;
  end;

  IByteScanner = interface(IByteReader)
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000033}']
    procedure UnreadByte;
  end;

implementation

end.
