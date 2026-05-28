unit nextpas.core.io;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.io.buffer,
  nextpas.core.io.util;

type
  TSeekOrigin = nextpas.core.io.base.TSeekOrigin;
  IReader = nextpas.core.io.intf.IReader;
  IWriter = nextpas.core.io.intf.IWriter;
  ISeeker = nextpas.core.io.intf.ISeeker;
  ICloser = nextpas.core.io.intf.ICloser;
  IFlusher = nextpas.core.io.intf.IFlusher;
  IStream = nextpas.core.io.intf.IStream;
  IReadCloser = nextpas.core.io.intf.IReadCloser;
  IWriteCloser = nextpas.core.io.intf.IWriteCloser;
  IReadWriter = nextpas.core.io.intf.IReadWriter;
  IReadWriteCloser = nextpas.core.io.intf.IReadWriteCloser;
  IReaderAt = nextpas.core.io.intf.IReaderAt;
  IWriterAt = nextpas.core.io.intf.IWriterAt;
  IByteReader = nextpas.core.io.intf.IByteReader;
  IByteWriter = nextpas.core.io.intf.IByteWriter;
  IStringWriter = nextpas.core.io.intf.IStringWriter;

{ Stream factories }
function BytesStream(const AInitialCapacity: SizeUInt = 256): IStream; inline;
function BytesStreamFrom(const AData: TBytes): IStream; inline;

{ Buffered I/O }
function BufferedReader(const AInner: IReader; const ABufSize: SizeUInt = DEFAULT_BUFFER_SIZE): IReader; inline;
function BufferedWriter(const AInner: IWriter; const ABufSize: SizeUInt = DEFAULT_BUFFER_SIZE): IWriter; inline;

{ Utilities }
function Copy(const ADst: IWriter; const ASrc: IReader): Int64; inline;
function CopyN(const ADst: IWriter; const ASrc: IReader; const AN: Int64): Int64; inline;
function ReadAll(const ASrc: IReader): TBytes; inline;
procedure ReadFull(const ASrc: IReader; var ABuf; const ACount: SizeUInt); inline;
function LimitReader(const AInner: IReader; const ALimit: Int64): IReader; inline;
function TeeReader(const AInner: IReader; const AWriter: IWriter): IReader; inline;
function MultiReader(const AReaders: array of IReader): IReader;
function MultiWriter(const AWriters: array of IWriter): IWriter;
function NopCloser(const AInner: IReader): IReadCloser; inline;
function Discard: IWriter; inline;
function NullReader: IReader; inline;

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

function Copy(const ADst: IWriter; const ASrc: IReader): Int64;
begin
  Result := nextpas.core.io.util.IoCopy(ADst, ASrc);
end;

function CopyN(const ADst: IWriter; const ASrc: IReader; const AN: Int64): Int64;
begin
  Result := nextpas.core.io.util.IoCopyN(ADst, ASrc, AN);
end;

function ReadAll(const ASrc: IReader): TBytes;
begin
  Result := nextpas.core.io.util.IoReadAll(ASrc);
end;

procedure ReadFull(const ASrc: IReader; var ABuf; const ACount: SizeUInt);
begin
  nextpas.core.io.util.IoReadFull(ASrc, ABuf, ACount);
end;

function LimitReader(const AInner: IReader; const ALimit: Int64): IReader;
begin
  Result := nextpas.core.io.util.IoLimitReader(AInner, ALimit);
end;

function TeeReader(const AInner: IReader; const AWriter: IWriter): IReader;
begin
  Result := nextpas.core.io.util.IoTeeReader(AInner, AWriter);
end;

function MultiReader(const AReaders: array of IReader): IReader;
begin
  Result := nextpas.core.io.util.IoMultiReader(AReaders);
end;

function MultiWriter(const AWriters: array of IWriter): IWriter;
begin
  Result := nextpas.core.io.util.IoMultiWriter(AWriters);
end;

function NopCloser(const AInner: IReader): IReadCloser;
begin
  Result := nextpas.core.io.util.IoNopCloser(AInner);
end;

function Discard: IWriter;
begin
  Result := nextpas.core.io.util.IoDiscard;
end;

function NullReader: IReader;
begin
  Result := nextpas.core.io.util.IoNullReader;
end;

end.
