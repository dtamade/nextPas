unit nextpas.core.bytes;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary,
  nextpas.core.bytes.builder;

type
  TEndianness = nextpas.core.bytes.base.TEndianness;
  IBytesBuilder = nextpas.core.bytes.builder.IBytesBuilder;

function CreateBytesBuilder(const AInitialCapacity: SizeUInt = BYTES_BUILDER_DEFAULT_CAPACITY): IBytesBuilder; inline;

function BytesEqual(const A, B: TBytes): Boolean; inline;
function BytesCompare(const A, B: TBytes): Integer; inline;
function BytesIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt; inline;
function BytesConcat(const A, B: TBytes): TBytes; inline;
function BytesStartsWith(const AData, APrefix: TBytes): Boolean; inline;
function BytesEndsWith(const AData, ASuffix: TBytes): Boolean; inline;

implementation

function CreateBytesBuilder(const AInitialCapacity: SizeUInt): IBytesBuilder;
begin
  Result := nextpas.core.bytes.builder.CreateBytesBuilder(AInitialCapacity);
end;

function BytesEqual(const A, B: TBytes): Boolean;
begin
  Result := nextpas.core.bytes.ops.BytesEqual(A, B);
end;

function BytesCompare(const A, B: TBytes): Integer;
begin
  Result := nextpas.core.bytes.ops.BytesCompare(A, B);
end;

function BytesIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt;
begin
  Result := nextpas.core.bytes.ops.BytesIndexOf(AData, ANeedle);
end;

function BytesConcat(const A, B: TBytes): TBytes;
begin
  Result := nextpas.core.bytes.ops.BytesConcat(A, B);
end;

function BytesStartsWith(const AData, APrefix: TBytes): Boolean;
begin
  Result := nextpas.core.bytes.ops.BytesStartsWith(AData, APrefix);
end;

function BytesEndsWith(const AData, ASuffix: TBytes): Boolean;
begin
  Result := nextpas.core.bytes.ops.BytesEndsWith(AData, ASuffix);
end;

end.
