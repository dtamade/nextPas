unit nextpas.core.io;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.io.buffer;

type
  TSeekOrigin = nextpas.core.io.base.TSeekOrigin;
  IReader = nextpas.core.io.intf.IReader;
  IWriter = nextpas.core.io.intf.IWriter;
  ISeeker = nextpas.core.io.intf.ISeeker;
  ICloser = nextpas.core.io.intf.ICloser;
  IFlusher = nextpas.core.io.intf.IFlusher;
  IStream = nextpas.core.io.intf.IStream;

function BytesStream(const AInitialCapacity: SizeUInt = 256): IStream; inline;
function BytesStreamFrom(const AData: TBytes): IStream; inline;
function BufferedReader(const AInner: IReader; const ABufSize: SizeUInt = DEFAULT_BUFFER_SIZE): IReader; inline;
function BufferedWriter(const AInner: IWriter; const ABufSize: SizeUInt = DEFAULT_BUFFER_SIZE): IWriter; inline;

implementation

function BytesStream(const AInitialCapacity: SizeUInt): IStream;
begin
  Result := nextpas.core.io.memory.CreateBytesStream(AInitialCapacity);
end;

function BytesStreamFrom(const AData: TBytes): IStream;
begin
  Result := nextpas.core.io.memory.CreateBytesStreamFrom(AData);
end;

function BufferedReader(const AInner: IReader; const ABufSize: SizeUInt): IReader;
begin
  Result := nextpas.core.io.buffer.CreateBufferedReader(AInner, ABufSize);
end;

function BufferedWriter(const AInner: IWriter; const ABufSize: SizeUInt): IWriter;
begin
  Result := nextpas.core.io.buffer.CreateBufferedWriter(AInner, ABufSize);
end;

end.
