unit nextpas.core.bytes;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.bytes.base,
  nextpas.core.bytes.intf,
  nextpas.core.bytes.buffer,
  nextpas.core.bytes.builder;

type
  TEndian = nextpas.core.bytes.base.TEndian;
  TByteOrder = nextpas.core.bytes.base.TByteOrder;
  IByteBuffer = nextpas.core.bytes.intf.IByteBuffer;
  IByteBuilder = nextpas.core.bytes.intf.IByteBuilder;

function ByteBuffer(const ACapacity: SizeUInt = 256): IByteBuffer; inline;
function ByteBufferFrom(const AData: TBytes): IByteBuffer; inline;
function ByteBuilder(const AInitialCapacity: SizeUInt = 256): IByteBuilder; inline;

implementation

function ByteBuffer(const ACapacity: SizeUInt): IByteBuffer;
begin
  Result := nextpas.core.bytes.buffer.CreateByteBuffer(ACapacity);
end;

function ByteBufferFrom(const AData: TBytes): IByteBuffer;
begin
  Result := nextpas.core.bytes.buffer.CreateByteBufferFrom(AData);
end;

function ByteBuilder(const AInitialCapacity: SizeUInt): IByteBuilder;
begin
  Result := nextpas.core.bytes.builder.CreateByteBuilder(AInitialCapacity);
end;

end.
