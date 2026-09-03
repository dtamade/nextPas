unit nextpas.core.bytes.ops.text;

{$I nextpas.core.settings.inc}
{ bytes.ops.text — string/bytes/var helpers single source (no raw Move)
  Leaf under bytes.ops, inline thin-forward from bytes.ops facade;
  zero-copy via SetString/PAnsiChar views, no duplicate Move (single source stays in bytes.ops).
  Not inline per red-line 2 where loop present; hot tiny helpers inline. }

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.binary;

function SpanToString(const ASpan: TByteSpan): string; inline;
function SpanToUTF8(const ASpan: TByteSpan): string; inline;
function BytesToString(const ABytes: TBytes): string; inline;
function BytesToUTF8(const ABytes: TBytes): string; inline;
function BytesSliceToString(const ABytes: TBytes; const AOffset, ALength: SizeUInt): string;
function TryClampSlice(const AOffset, ALength, ATotal: SizeUInt; out AClampedLen: SizeUInt): Boolean; inline;
function BigEndianUnicodeBytesToString(const AData: TBytes): string;
function AsciiLowerString(const S: string): string;
function AsciiUpperString(const S: string): string;
function VarType(const V: Variant): TVarType; inline;
function VarIsNull(const V: Variant): Boolean; inline;
function VarIsEmpty(const V: Variant): Boolean; inline;
function VarIsClear(const V: Variant): Boolean; inline;
function HTonN(AValue: Word): Word; overload; inline;
function HTonN(AValue: LongWord): LongWord; overload; inline;
function NToHs(AValue: Word): Word; overload; inline;
function NToHs(AValue: LongWord): LongWord; overload; inline;
function FNV1a32(const AData: PByte; const ALen: SizeUInt): UInt32; inline;
function FNV1a32Bytes(const AData: TBytes): UInt32; inline;

implementation

uses
  nextpas.core.simd,
  nextpas.core.mem.dynarray;

type
  TVarDataView = packed record
    VType: Word;
    Reserved: array[0..13] of Byte;
  end;
  PVarDataView = ^TVarDataView;
  PVarData = ^TVarData;

function SpanToString(const ASpan: TByteSpan): string; inline;
begin
  if ASpan.Len = 0 then
    Exit('');
  SetString(Result, PAnsiChar(ASpan.Data), ASpan.Len);
end;

function SpanToUTF8(const ASpan: TByteSpan): string; inline;
begin
  Result := SpanToString(ASpan);
end;

function BytesToString(const ABytes: TBytes): string; inline;
begin
  Result := SpanToString(TByteSpan.FromBytes(ABytes));
end;

function BytesToUTF8(const ABytes: TBytes): string;
begin
  Result := BytesToString(ABytes);
end;

function BytesSliceToString(const ABytes: TBytes; const AOffset, ALength: SizeUInt): string;
var
  LSpan: TByteSpan;
begin
  if ALength = 0 then
    Exit('');
  LSpan := TByteSpan.FromBytes(ABytes).Slice(AOffset, ALength);
  Result := SpanToString(LSpan);
end;

function TryClampSlice(const AOffset, ALength, ATotal: SizeUInt; out AClampedLen: SizeUInt): Boolean; inline;
begin
  if AOffset >= ATotal then
  begin
    AClampedLen := 0;
    Exit(False);
  end;
  if ALength > ATotal - AOffset then
    AClampedLen := ATotal - AOffset
  else
    AClampedLen := ALength;
  Result := True;
end;

function BigEndianUnicodeBytesToString(const AData: TBytes): string;
var
  I, LCount: SizeInt;
  LWChars: array of WideChar;
begin
  Result := '';
  LCount := Length(AData) div 2;
  if LCount = 0 then
    Exit;
  SetLength(LWChars, LCount);
  for I := 0 to LCount - 1 do
    LWChars[I] := WideChar((UInt16(AData[I * 2]) shl 8) or UInt16(AData[I * 2 + 1]));
  SetString(Result, PWideChar(LWChars), LCount);
end;

function AsciiLowerString(const S: string): string;
begin
  if S = '' then
    Exit('');
  Result := SpanToString(TByteSpan.Create(PByte(PAnsiChar(S)), SizeUInt(Length(S))));
  if Length(Result) > 0 then
    ToLowerAscii(Pointer(Result), SizeUInt(Length(Result)));
end;

function AsciiUpperString(const S: string): string;
begin
  if S = '' then
    Exit('');
  Result := SpanToString(TByteSpan.Create(PByte(PAnsiChar(S)), SizeUInt(Length(S))));
  if Length(Result) > 0 then
    ToUpperAscii(Pointer(Result), SizeUInt(Length(Result)));
end;

function VarType(const V: Variant): TVarType; inline;
begin
  Result := PVarData(@V)^.VType and varTypeMask;
end;

function VarIsNull(const V: Variant): Boolean; inline;
begin
  Result := (PVarData(@V)^.VType and varTypeMask) = varNull;
end;

function VarIsEmpty(const V: Variant): Boolean; inline;
begin
  Result := (PVarData(@V)^.VType and varTypeMask) = varEmpty;
end;

function VarIsClear(const V: Variant): Boolean; inline;
var
  LType: Word;
begin
  LType := PVarData(@V)^.VType and varTypeMask;
  Result := (LType = varEmpty) or (LType = varNull);
end;

function HTonN(AValue: Word): Word; inline;
begin
  Result := Word(nextpas.core.bytes.binary.HostToNetwork16(UInt16(AValue)));
end;

function HTonN(AValue: LongWord): LongWord; inline;
begin
  Result := LongWord(nextpas.core.bytes.binary.HostToNetwork32Words(UInt32(AValue)));
end;

function NToHs(AValue: Word): Word; inline;
begin
  Result := Word(nextpas.core.bytes.binary.NetworkToHost16(UInt16(AValue)));
end;

function NToHs(AValue: LongWord): LongWord; inline;
begin
  Result := LongWord(nextpas.core.bytes.binary.NetworkToHost32Words(UInt32(AValue)));
end;

function FNV1a32(const AData: PByte; const ALen: SizeUInt): UInt32; inline;
begin
  Result := HashBytes(AData, ALen);
end;

function FNV1a32Bytes(const AData: TBytes): UInt32; inline;
begin
  if Length(AData) = 0 then
    Result := HashBytes(nil, 0)
  else
    Result := HashBytes(@AData[0], SizeUInt(Length(AData)));
end;

end.
