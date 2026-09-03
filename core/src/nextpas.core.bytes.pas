unit nextpas.core.bytes;
{**
 * @desc 字节容器门面：Buffer、Builder、字节序操作。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary,
  nextpas.core.bytes.builder,
  nextpas.core.bytes.cursor,
  nextpas.core.bytes.stream,
  nextpas.core.bytes.framing;

type
  TEndianness = nextpas.core.bytes.base.TEndianness;
  IBytesBuilder = nextpas.core.bytes.builder.IBytesBuilder;
  IByteCursor = nextpas.core.bytes.cursor.IByteCursor;
  TByteStreamBuf = nextpas.core.bytes.stream.TByteStreamBuf;
  TWireBuffer = nextpas.core.bytes.framing.TWireBuffer;

const
  endLittle = nextpas.core.bytes.base.endLittle;
  endBig = nextpas.core.bytes.base.endBig;
  NATIVE_ENDIAN = nextpas.core.bytes.base.NATIVE_ENDIAN;
  WIRE_BUFFER_COMPACT_OFFSET_ABSOLUTE = nextpas.core.bytes.framing.WIRE_BUFFER_COMPACT_OFFSET_ABSOLUTE;
  WIRE_BUFFER_COMPACT_OFFSET_HALF = nextpas.core.bytes.framing.WIRE_BUFFER_COMPACT_OFFSET_HALF;
  WIRE_BUFFER_DEFAULT_MAX = nextpas.core.bytes.framing.WIRE_BUFFER_DEFAULT_MAX;

{ Builder — single source via bytes.builder, inline zero-copy }
function MakeBytesBuilder(const AInitialCapacity: SizeUInt = BYTES_BUILDER_DEFAULT_CAPACITY): IBytesBuilder; inline;
function CreateBytesBuilder(const AInitialCapacity: SizeUInt = BYTES_BUILDER_DEFAULT_CAPACITY): IBytesBuilder; inline; deprecated 'Use MakeBytesBuilder';

{ Cursor — single source via bytes.cursor, inline }
function NewByteCursor(const AData: TBytes): IByteCursor; inline;
function NewByteCursorAt(const AData: PByte; ALen: SizeUInt): IByteCursor; inline;

{ Span ops — single source via bytes.ops, inline/zero-copy TByteSpan view }
function SpanEqual(const A, B: TByteSpan): Boolean; inline;
function SpanCompare(const A, B: TByteSpan): Integer; inline;
function SpanIndexOf(const AHaystack: TByteSpan; const ANeedle: Byte): SizeInt; inline;
function SpanIndexOfSpan(const AHaystack, ANeedle: TByteSpan): SizeInt; inline;
function SpanLastIndexOfSpan(const AHaystack, ANeedle: TByteSpan): SizeInt; inline;
function SpanContains(const AHaystack: TByteSpan; const ANeedle: Byte): Boolean; inline;
function SpanStartsWith(const AData, APrefix: TByteSpan): Boolean; inline;
function SpanEndsWith(const AData, ASuffix: TByteSpan): Boolean; inline;
procedure SpanFill(const ASpan: TByteSpan; const AValue: Byte); inline;
procedure SpanReverse(const ASpan: TByteSpan); inline;
function SpanConcat(const A, B: TByteSpan): TBytes; inline;
function SpanCopySlice(const ASpan: TByteSpan; const AOffset, ALength: SizeUInt): TBytes; inline;
function SpanClone(const ASpan: TByteSpan): TBytes; inline;

{ TBytes convenience — single source via bytes.ops, inline thin-forward to Span }
function BytesEqual(const A, B: TBytes): Boolean; inline;
function BytesCompare(const A, B: TBytes): Integer; inline;
function BytesIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt; inline;
function BytesConcat(const A, B: TBytes): TBytes; inline;
function BytesStartsWith(const AData, APrefix: TBytes): Boolean; inline;
function BytesEndsWith(const AData, ASuffix: TBytes): Boolean; inline;

{ String <-> bytes — single source via bytes.ops (INV-5), inline thin-forward, zero-copy TByteSpan view; no duplicate Move/SetLength — owner bytes.ops only }
function SpanToString(const ASpan: TByteSpan): string; inline;
function SpanToUTF8(const ASpan: TByteSpan): string; inline;
function BytesToString(const ABytes: TBytes): string; inline;
function StringToBytes(const AText: string): TBytes; inline;
function BytesSliceToString(const ABytes: TBytes; const AOffset,
  ALength: SizeUInt): string; inline;

{ Unsigned helpers — single source via bytes.ops, inline }
function StripLeadingZero(const AData: TBytes): TBytes; inline;
function StripLeadingZeroBytes(const AData: TBytes): TBytes; inline;
function CompareUnsigned(const ALeft, ARight: TBytes): Integer; inline;
function CompareUnsignedBytes(const ALeft, ARight: TBytes): Integer; inline;
function UnsignedEqual(const ALeft, ARight: TBytes): Boolean; inline;
function UnsignedBytesEqual(const ALeft, ARight: TBytes): Boolean; inline;

{ Binary: swap — single source via bytes.binary, inline zero-copy register }
function SwapUInt16(const AValue: UInt16): UInt16; inline;
function SwapUInt32(const AValue: UInt32): UInt32; inline;
function SwapUInt64(const AValue: UInt64): UInt64; inline;

{ Binary: endian conversion — single source via bytes.binary, inline }
function ToEndian16(const AValue: UInt16; const AEndian: TEndianness): UInt16; inline;
function ToEndian32(const AValue: UInt32; const AEndian: TEndianness): UInt32; inline;
function ToEndian64(const AValue: UInt64; const AEndian: TEndianness): UInt64; inline;
function FromEndian16(const AValue: UInt16; const AEndian: TEndianness): UInt16; inline;
function FromEndian32(const AValue: UInt32; const AEndian: TEndianness): UInt32; inline;
function FromEndian64(const AValue: UInt64; const AEndian: TEndianness): UInt64; inline;

{ Binary: read from pointer — single source via bytes.binary, inline }
function ReadUInt16LE(const ASrc: PByte): UInt16; inline;
function ReadUInt16BE(const ASrc: PByte): UInt16; inline;
function ReadUInt32LE(const ASrc: PByte): UInt32; inline;
function ReadUInt32BE(const ASrc: PByte): UInt32; inline;
function ReadUInt64LE(const ASrc: PByte): UInt64; inline;
function ReadUInt64BE(const ASrc: PByte): UInt64; inline;

{ Binary: write to pointer — single source via bytes.binary, inline }
procedure WriteUInt16LE(const ADst: PByte; const AValue: UInt16); inline;
procedure WriteUInt16BE(const ADst: PByte; const AValue: UInt16); inline;
procedure WriteUInt32LE(const ADst: PByte; const AValue: UInt32); inline;
procedure WriteUInt32BE(const ADst: PByte; const AValue: UInt32); inline;
procedure WriteUInt64LE(const ADst: PByte; const AValue: UInt64); inline;
procedure WriteUInt64BE(const ADst: PByte; const AValue: UInt64); inline;

{ Binary: advancing cursor read — single source via bytes.binary, inline }
function TryReadUInt8(var ASpan: TByteSpan; out AValue: Byte): Boolean; inline;
function TryReadUInt16LE(var ASpan: TByteSpan; out AValue: UInt16): Boolean; inline;
function TryReadUInt16BE(var ASpan: TByteSpan; out AValue: UInt16): Boolean; inline;
function TryReadUInt32LE(var ASpan: TByteSpan; out AValue: UInt32): Boolean; inline;
function TryReadUInt32BE(var ASpan: TByteSpan; out AValue: UInt32): Boolean; inline;
function TryReadUInt64LE(var ASpan: TByteSpan; out AValue: UInt64): Boolean; inline;
function TryReadUInt64BE(var ASpan: TByteSpan; out AValue: UInt64): Boolean; inline;

{ Binary: advancing cursor write — single source via bytes.binary, inline }
function TryWriteUInt8(var ASpan: TByteSpan; const AValue: Byte): Boolean; inline;
function TryWriteUInt16LE(var ASpan: TByteSpan; const AValue: UInt16): Boolean; inline;
function TryWriteUInt16BE(var ASpan: TByteSpan; const AValue: UInt16): Boolean; inline;
function TryWriteUInt32LE(var ASpan: TByteSpan; const AValue: UInt32): Boolean; inline;
function TryWriteUInt32BE(var ASpan: TByteSpan; const AValue: UInt32): Boolean; inline;
function TryWriteUInt64LE(var ASpan: TByteSpan; const AValue: UInt64): Boolean; inline;
function TryWriteUInt64BE(var ASpan: TByteSpan; const AValue: UInt64): Boolean; inline;

{ Wire framing: 4B BE length-prefix }
function WireEncodeFrame(const APayload: TBytes): TBytes; inline;
procedure WireAppendEncoded(var ADest: TBytes; const APayload: TBytes); inline;

implementation

{ Builder }

function MakeBytesBuilder(const AInitialCapacity: SizeUInt): IBytesBuilder; inline;
begin
  Result := nextpas.core.bytes.builder.CreateBytesBuilder(AInitialCapacity);
end;

function CreateBytesBuilder(const AInitialCapacity: SizeUInt): IBytesBuilder; inline;
begin
  Result := MakeBytesBuilder(AInitialCapacity);
end;

{ Cursor }

function NewByteCursor(const AData: TBytes): IByteCursor; inline;
begin
  Result := nextpas.core.bytes.cursor.NewByteCursor(AData);
end;

function NewByteCursorAt(const AData: PByte; ALen: SizeUInt): IByteCursor; inline;
begin
  Result := nextpas.core.bytes.cursor.NewByteCursorAt(AData, ALen);
end;

{ Span ops }

function SpanEqual(const A, B: TByteSpan): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.SpanEqual(A, B);
end;

function SpanCompare(const A, B: TByteSpan): Integer; inline;
begin
  Result := nextpas.core.bytes.ops.SpanCompare(A, B);
end;

function SpanIndexOf(const AHaystack: TByteSpan; const ANeedle: Byte): SizeInt; inline;
begin
  Result := nextpas.core.bytes.ops.SpanIndexOf(AHaystack, ANeedle);
end;

function SpanIndexOfSpan(const AHaystack, ANeedle: TByteSpan): SizeInt; inline;
begin
  Result := nextpas.core.bytes.ops.SpanIndexOfSpan(AHaystack, ANeedle);
end;

function SpanLastIndexOfSpan(const AHaystack, ANeedle: TByteSpan): SizeInt; inline;
begin
  Result := nextpas.core.bytes.ops.SpanLastIndexOfSpan(AHaystack, ANeedle);
end;

function SpanContains(const AHaystack: TByteSpan; const ANeedle: Byte): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.SpanContains(AHaystack, ANeedle);
end;

function SpanStartsWith(const AData, APrefix: TByteSpan): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.SpanStartsWith(AData, APrefix);
end;

function SpanEndsWith(const AData, ASuffix: TByteSpan): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.SpanEndsWith(AData, ASuffix);
end;

procedure SpanFill(const ASpan: TByteSpan; const AValue: Byte); inline;
begin
  nextpas.core.bytes.ops.SpanFill(ASpan, AValue);
end;

procedure SpanReverse(const ASpan: TByteSpan); inline;
begin
  nextpas.core.bytes.ops.SpanReverse(ASpan);
end;

function SpanConcat(const A, B: TByteSpan): TBytes; inline;
begin
  Result := nextpas.core.bytes.ops.SpanConcat(A, B);
end;

function SpanCopySlice(const ASpan: TByteSpan; const AOffset, ALength: SizeUInt): TBytes; inline;
begin
  Result := nextpas.core.bytes.ops.SpanCopySlice(ASpan, AOffset, ALength);
end;

function SpanClone(const ASpan: TByteSpan): TBytes; inline;
begin
  Result := nextpas.core.bytes.ops.SpanClone(ASpan);
end;

{ TBytes convenience }

function BytesEqual(const A, B: TBytes): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.BytesEqual(A, B);
end;

function BytesCompare(const A, B: TBytes): Integer; inline;
begin
  Result := nextpas.core.bytes.ops.BytesCompare(A, B);
end;

function BytesIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt; inline;
begin
  Result := nextpas.core.bytes.ops.BytesIndexOf(AData, ANeedle);
end;

function BytesConcat(const A, B: TBytes): TBytes; inline;
begin
  Result := nextpas.core.bytes.ops.BytesConcat(A, B);
end;

function BytesStartsWith(const AData, APrefix: TBytes): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.BytesStartsWith(AData, APrefix);
end;

function BytesEndsWith(const AData, ASuffix: TBytes): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.BytesEndsWith(AData, ASuffix);
end;

{ String <-> bytes }

function SpanToString(const ASpan: TByteSpan): string; inline;
begin
  Result := nextpas.core.bytes.ops.SpanToString(ASpan);
end;

function SpanToUTF8(const ASpan: TByteSpan): string; inline;
begin
  Result := nextpas.core.bytes.ops.SpanToUTF8(ASpan);
end;

function BytesToString(const ABytes: TBytes): string; inline;
begin
  Result := nextpas.core.bytes.ops.BytesToString(ABytes);
end;

function StringToBytes(const AText: string): TBytes; inline;
begin
  Result := nextpas.core.bytes.ops.StringToBytes(AText);
end;

function BytesSliceToString(const ABytes: TBytes; const AOffset,
  ALength: SizeUInt): string; inline;
begin
  Result := nextpas.core.bytes.ops.BytesSliceToString(ABytes, AOffset, ALength);
end;

{ Unsigned helpers }

function StripLeadingZero(const AData: TBytes): TBytes; inline;
begin
  Result := nextpas.core.bytes.ops.StripLeadingZero(AData);
end;

function StripLeadingZeroBytes(const AData: TBytes): TBytes; inline;
begin
  Result := nextpas.core.bytes.ops.StripLeadingZeroBytes(AData);
end;

function CompareUnsigned(const ALeft, ARight: TBytes): Integer; inline;
begin
  Result := nextpas.core.bytes.ops.CompareUnsigned(ALeft, ARight);
end;

function CompareUnsignedBytes(const ALeft, ARight: TBytes): Integer; inline;
begin
  Result := nextpas.core.bytes.ops.CompareUnsignedBytes(ALeft, ARight);
end;

function UnsignedEqual(const ALeft, ARight: TBytes): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.UnsignedEqual(ALeft, ARight);
end;

function UnsignedBytesEqual(const ALeft, ARight: TBytes): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.UnsignedBytesEqual(ALeft, ARight);
end;

{ Binary: swap }

function SwapUInt16(const AValue: UInt16): UInt16; inline;
begin
  Result := nextpas.core.bytes.binary.SwapUInt16(AValue);
end;

function SwapUInt32(const AValue: UInt32): UInt32; inline;
begin
  Result := nextpas.core.bytes.binary.SwapUInt32(AValue);
end;

function SwapUInt64(const AValue: UInt64): UInt64; inline;
begin
  Result := nextpas.core.bytes.binary.SwapUInt64(AValue);
end;

{ Binary: endian conversion }

function ToEndian16(const AValue: UInt16; const AEndian: TEndianness): UInt16; inline;
begin
  Result := nextpas.core.bytes.binary.ToEndian16(AValue, AEndian);
end;

function ToEndian32(const AValue: UInt32; const AEndian: TEndianness): UInt32; inline;
begin
  Result := nextpas.core.bytes.binary.ToEndian32(AValue, AEndian);
end;

function ToEndian64(const AValue: UInt64; const AEndian: TEndianness): UInt64; inline;
begin
  Result := nextpas.core.bytes.binary.ToEndian64(AValue, AEndian);
end;

function FromEndian16(const AValue: UInt16; const AEndian: TEndianness): UInt16; inline;
begin
  Result := nextpas.core.bytes.binary.FromEndian16(AValue, AEndian);
end;

function FromEndian32(const AValue: UInt32; const AEndian: TEndianness): UInt32; inline;
begin
  Result := nextpas.core.bytes.binary.FromEndian32(AValue, AEndian);
end;

function FromEndian64(const AValue: UInt64; const AEndian: TEndianness): UInt64; inline;
begin
  Result := nextpas.core.bytes.binary.FromEndian64(AValue, AEndian);
end;

{ Binary: read }

function ReadUInt16LE(const ASrc: PByte): UInt16; inline;
begin
  Result := nextpas.core.bytes.binary.ReadUInt16LE(ASrc);
end;

function ReadUInt16BE(const ASrc: PByte): UInt16; inline;
begin
  Result := nextpas.core.bytes.binary.ReadUInt16BE(ASrc);
end;

function ReadUInt32LE(const ASrc: PByte): UInt32; inline;
begin
  Result := nextpas.core.bytes.binary.ReadUInt32LE(ASrc);
end;

function ReadUInt32BE(const ASrc: PByte): UInt32; inline;
begin
  Result := nextpas.core.bytes.binary.ReadUInt32BE(ASrc);
end;

function ReadUInt64LE(const ASrc: PByte): UInt64; inline;
begin
  Result := nextpas.core.bytes.binary.ReadUInt64LE(ASrc);
end;

function ReadUInt64BE(const ASrc: PByte): UInt64; inline;
begin
  Result := nextpas.core.bytes.binary.ReadUInt64BE(ASrc);
end;

{ Binary: write }

procedure WriteUInt16LE(const ADst: PByte; const AValue: UInt16); inline;
begin
  nextpas.core.bytes.binary.WriteUInt16LE(ADst, AValue);
end;

procedure WriteUInt16BE(const ADst: PByte; const AValue: UInt16); inline;
begin
  nextpas.core.bytes.binary.WriteUInt16BE(ADst, AValue);
end;

procedure WriteUInt32LE(const ADst: PByte; const AValue: UInt32); inline;
begin
  nextpas.core.bytes.binary.WriteUInt32LE(ADst, AValue);
end;

procedure WriteUInt32BE(const ADst: PByte; const AValue: UInt32); inline;
begin
  nextpas.core.bytes.binary.WriteUInt32BE(ADst, AValue);
end;

procedure WriteUInt64LE(const ADst: PByte; const AValue: UInt64); inline;
begin
  nextpas.core.bytes.binary.WriteUInt64LE(ADst, AValue);
end;

procedure WriteUInt64BE(const ADst: PByte; const AValue: UInt64); inline;
begin
  nextpas.core.bytes.binary.WriteUInt64BE(ADst, AValue);
end;

{ Binary: TryRead }

function TryReadUInt8(var ASpan: TByteSpan; out AValue: Byte): Boolean; inline;
begin
  Result := nextpas.core.bytes.binary.TryReadUInt8(ASpan, AValue);
end;

function TryReadUInt16LE(var ASpan: TByteSpan; out AValue: UInt16): Boolean; inline;
begin
  Result := nextpas.core.bytes.binary.TryReadUInt16LE(ASpan, AValue);
end;

function TryReadUInt16BE(var ASpan: TByteSpan; out AValue: UInt16): Boolean; inline;
begin
  Result := nextpas.core.bytes.binary.TryReadUInt16BE(ASpan, AValue);
end;

function TryReadUInt32LE(var ASpan: TByteSpan; out AValue: UInt32): Boolean; inline;
begin
  Result := nextpas.core.bytes.binary.TryReadUInt32LE(ASpan, AValue);
end;

function TryReadUInt32BE(var ASpan: TByteSpan; out AValue: UInt32): Boolean; inline;
begin
  Result := nextpas.core.bytes.binary.TryReadUInt32BE(ASpan, AValue);
end;

function TryReadUInt64LE(var ASpan: TByteSpan; out AValue: UInt64): Boolean; inline;
begin
  Result := nextpas.core.bytes.binary.TryReadUInt64LE(ASpan, AValue);
end;

function TryReadUInt64BE(var ASpan: TByteSpan; out AValue: UInt64): Boolean; inline;
begin
  Result := nextpas.core.bytes.binary.TryReadUInt64BE(ASpan, AValue);
end;

{ Binary: TryWrite }

function TryWriteUInt8(var ASpan: TByteSpan; const AValue: Byte): Boolean; inline;
begin
  Result := nextpas.core.bytes.binary.TryWriteUInt8(ASpan, AValue);
end;

function TryWriteUInt16LE(var ASpan: TByteSpan; const AValue: UInt16): Boolean; inline;
begin
  Result := nextpas.core.bytes.binary.TryWriteUInt16LE(ASpan, AValue);
end;

function TryWriteUInt16BE(var ASpan: TByteSpan; const AValue: UInt16): Boolean; inline;
begin
  Result := nextpas.core.bytes.binary.TryWriteUInt16BE(ASpan, AValue);
end;

function TryWriteUInt32LE(var ASpan: TByteSpan; const AValue: UInt32): Boolean; inline;
begin
  Result := nextpas.core.bytes.binary.TryWriteUInt32LE(ASpan, AValue);
end;

function TryWriteUInt32BE(var ASpan: TByteSpan; const AValue: UInt32): Boolean; inline;
begin
  Result := nextpas.core.bytes.binary.TryWriteUInt32BE(ASpan, AValue);
end;

function TryWriteUInt64LE(var ASpan: TByteSpan; const AValue: UInt64): Boolean; inline;
begin
  Result := nextpas.core.bytes.binary.TryWriteUInt64LE(ASpan, AValue);
end;

function TryWriteUInt64BE(var ASpan: TByteSpan; const AValue: UInt64): Boolean; inline;
begin
  Result := nextpas.core.bytes.binary.TryWriteUInt64BE(ASpan, AValue);
end;

{ Wire framing }

function WireEncodeFrame(const APayload: TBytes): TBytes;
begin
  Result := nextpas.core.bytes.framing.WireEncodeFrame(APayload);
end;

procedure WireAppendEncoded(var ADest: TBytes; const APayload: TBytes);
begin
  nextpas.core.bytes.framing.WireAppendEncoded(ADest, APayload);
end;

end.
