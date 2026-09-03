unit nextpas.core.bytes.builder;

{$I nextpas.core.settings.inc}
{ Single-source: growth via bytes.ops.BytesGrowCapacity (INV-2) amortized O(1) geometric; Move/Fill via bytes.ops.BytesCopy/BytesZero+SpanFill inline single source (INV-5) zero-copy SIMD-optimized; owner bytes.ops.
  perf: WrittenSpan zero-copy view (single TByteSpan.Create, no alloc), AppendByte/AppendUInt* inline tiny stores (no Move) hot path; AppendBytes/AppendFill/ToBytes not inline per red-line 1/2 (BytesCopy/BytesZero+SpanFill/SetLength + Grow loop I-Cache) single BytesCopy/BytesZero inline zero-copy single source (Fill via SpanFill for arbitrary, BytesZero for 0 — no raw FillChar, gate: check_bytes_ops_source_contract.py); Grow not inline per red-line 2 (while); stability: sized FreeMemOf on Destroy, Clear/Reserve/Truncate keep capacity. }
{ CONTRACT: core/docs/bytes/CONTRACT.md 1.1 — L1 bytes, four-piece base→builder→facade, no intf/ffi (on-demand). }

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

type
  IBytesBuilder = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetLength: SizeUInt;
    function GetCapacity: SizeUInt;
    function GetData: PByte;

    procedure AppendByte(const AValue: Byte); inline;
    procedure AppendBytes(const AData: PByte; const ACount: SizeUInt);
    procedure AppendSpan(const ASpan: TByteSpan); inline;
    procedure AppendUInt16LE(const AValue: UInt16); inline;
    procedure AppendUInt16BE(const AValue: UInt16); inline;
    procedure AppendUInt32LE(const AValue: UInt32); inline;
    procedure AppendUInt32BE(const AValue: UInt32); inline;
    procedure AppendUInt64LE(const AValue: UInt64); inline;
    procedure AppendUInt64BE(const AValue: UInt64); inline;
    procedure AppendFill(const AValue: Byte; const ACount: SizeUInt);

    { perf: WrittenSpan zero-copy view (no alloc, single TByteSpan.Create); ToBytes single SetLength+BytesCopy inline zero-copy single source via bytes.ops not inline per red-line 1/2 }
    function WrittenSpan: TByteSpan; inline;
    function ToBytes: TBytes;

    procedure Clear;
    procedure Reserve(const AAdditional: SizeUInt);
    procedure Truncate(const ANewLen: SizeUInt);

    property Length: SizeUInt read GetLength;
    property Capacity: SizeUInt read GetCapacity;
    property Data: PByte read GetData;
  end;

function CreateBytesBuilder(const AInitialCapacity: SizeUInt = BYTES_BUILDER_DEFAULT_CAPACITY): IBytesBuilder;
function CreateBytesBuilderWith(const AAllocator: TMemAllocator; const AInitialCapacity: SizeUInt = BYTES_BUILDER_DEFAULT_CAPACITY): IBytesBuilder;

implementation

uses
  nextpas.core.mem,
  nextpas.core.bytes.ops;

type
  TBytesBuilderImpl = class(TRefCountedObject, IBytesBuilder)
  private
    FPtr: PByte;
    FLen: SizeUInt;
    FCap: SizeUInt;
    FAllocator: TMemAllocator;
    procedure Grow(const ANeeded: SizeUInt);
  public
    constructor Create(const AAllocator: TMemAllocator; const AInitialCapacity: SizeUInt);
    destructor Destroy; override;

    function GetLength: SizeUInt;
    function GetCapacity: SizeUInt;
    function GetData: PByte;

    procedure AppendByte(const AValue: Byte); inline;
    procedure AppendBytes(const AData: PByte; const ACount: SizeUInt);
    procedure AppendSpan(const ASpan: TByteSpan); inline;
    procedure AppendUInt16LE(const AValue: UInt16); inline;
    procedure AppendUInt16BE(const AValue: UInt16); inline;
    procedure AppendUInt32LE(const AValue: UInt32); inline;
    procedure AppendUInt32BE(const AValue: UInt32); inline;
    procedure AppendUInt64LE(const AValue: UInt64); inline;
    procedure AppendUInt64BE(const AValue: UInt64); inline;
    procedure AppendFill(const AValue: Byte; const ACount: SizeUInt);

    function WrittenSpan: TByteSpan; inline;
    function ToBytes: TBytes;

    procedure Clear;
    procedure Reserve(const AAdditional: SizeUInt);
    procedure Truncate(const ANewLen: SizeUInt);
  end;

function CreateBytesBuilder(const AInitialCapacity: SizeUInt): IBytesBuilder;
begin
  Result := TBytesBuilderImpl.Create(nextpas.core.mem.DefaultAllocator, AInitialCapacity);
end;

function CreateBytesBuilderWith(const AAllocator: TMemAllocator; const AInitialCapacity: SizeUInt): IBytesBuilder;
begin
  Result := TBytesBuilderImpl.Create(AAllocator, AInitialCapacity);
end;

{ TBytesBuilderImpl }

constructor TBytesBuilderImpl.Create(const AAllocator: TMemAllocator; const AInitialCapacity: SizeUInt);
begin
  inherited Create;
  FAllocator := AAllocator;
  if AInitialCapacity > 0 then
    FPtr := FAllocator.GetMem(AInitialCapacity)
  else
    FPtr := nil;
  FLen := 0;
  FCap := AInitialCapacity;
end;

destructor TBytesBuilderImpl.Destroy;
begin
  if FPtr <> nil then
  begin
    { Sized free when size known (same pattern as text.builder FreeMemOf). }
    FreeMemOf(FAllocator, FPtr, FCap);
    FPtr := nil;
  end;
  inherited;
end;

procedure TBytesBuilderImpl.Grow(const ANeeded: SizeUInt);
var
  LNewCap: SizeUInt;
begin
  // not inline per red-line 2: while loop I-Cache bloat; single source via bytes.ops.BytesGrowCapacity (INV-2, amortized O(1) geometric)
  if FLen + ANeeded <= FCap then
    Exit;
  LNewCap := nextpas.core.bytes.ops.BytesGrowCapacity(FCap, FLen + ANeeded);
  FPtr := ReallocMemOf(FAllocator, FPtr, FCap, LNewCap);
  FCap := LNewCap;
end;

function TBytesBuilderImpl.GetLength: SizeUInt;
begin
  Result := FLen;
end;

function TBytesBuilderImpl.GetCapacity: SizeUInt;
begin
  Result := FCap;
end;

function TBytesBuilderImpl.GetData: PByte;
begin
  Result := FPtr;
end;

procedure TBytesBuilderImpl.AppendByte(const AValue: Byte); inline;
begin
  Grow(1);
  FPtr[FLen] := AValue;
  Inc(FLen);
end;

procedure TBytesBuilderImpl.AppendBytes(const AData: PByte; const ACount: SizeUInt);
begin
  // not inline per red-line 1/2: BytesCopy + Grow loop I-Cache bloat; single BytesCopy inline zero-copy single source via bytes.ops (INV-5) SIMD-optimized, no raw Move
  if ACount = 0 then Exit;
  Grow(ACount);
  nextpas.core.bytes.ops.BytesCopy(FPtr + FLen, AData, ACount);
  Inc(FLen, ACount);
end;

procedure TBytesBuilderImpl.AppendSpan(const ASpan: TByteSpan); inline;
begin
  AppendBytes(ASpan.Data, ASpan.Len);
end;

procedure TBytesBuilderImpl.AppendUInt16LE(const AValue: UInt16); inline;
begin
  Grow(2);
  FPtr[FLen]     := Byte(AValue);
  FPtr[FLen + 1] := Byte(AValue shr 8);
  Inc(FLen, 2);
end;

procedure TBytesBuilderImpl.AppendUInt16BE(const AValue: UInt16); inline;
begin
  Grow(2);
  FPtr[FLen]     := Byte(AValue shr 8);
  FPtr[FLen + 1] := Byte(AValue);
  Inc(FLen, 2);
end;

procedure TBytesBuilderImpl.AppendUInt32LE(const AValue: UInt32); inline;
begin
  Grow(4);
  FPtr[FLen]     := Byte(AValue);
  FPtr[FLen + 1] := Byte(AValue shr 8);
  FPtr[FLen + 2] := Byte(AValue shr 16);
  FPtr[FLen + 3] := Byte(AValue shr 24);
  Inc(FLen, 4);
end;

procedure TBytesBuilderImpl.AppendUInt32BE(const AValue: UInt32); inline;
begin
  Grow(4);
  FPtr[FLen]     := Byte(AValue shr 24);
  FPtr[FLen + 1] := Byte(AValue shr 16);
  FPtr[FLen + 2] := Byte(AValue shr 8);
  FPtr[FLen + 3] := Byte(AValue);
  Inc(FLen, 4);
end;

procedure TBytesBuilderImpl.AppendUInt64LE(const AValue: UInt64); inline;
begin
  Grow(8);
  FPtr[FLen]     := Byte(AValue);
  FPtr[FLen + 1] := Byte(AValue shr 8);
  FPtr[FLen + 2] := Byte(AValue shr 16);
  FPtr[FLen + 3] := Byte(AValue shr 24);
  FPtr[FLen + 4] := Byte(AValue shr 32);
  FPtr[FLen + 5] := Byte(AValue shr 40);
  FPtr[FLen + 6] := Byte(AValue shr 48);
  FPtr[FLen + 7] := Byte(AValue shr 56);
  Inc(FLen, 8);
end;

procedure TBytesBuilderImpl.AppendUInt64BE(const AValue: UInt64); inline;
begin
  Grow(8);
  FPtr[FLen]     := Byte(AValue shr 56);
  FPtr[FLen + 1] := Byte(AValue shr 48);
  FPtr[FLen + 2] := Byte(AValue shr 40);
  FPtr[FLen + 3] := Byte(AValue shr 32);
  FPtr[FLen + 4] := Byte(AValue shr 24);
  FPtr[FLen + 5] := Byte(AValue shr 16);
  FPtr[FLen + 6] := Byte(AValue shr 8);
  FPtr[FLen + 7] := Byte(AValue);
  Inc(FLen, 8);
end;

procedure TBytesBuilderImpl.AppendFill(const AValue: Byte; const ACount: SizeUInt);
begin
  // not inline per red-line 1/2: Fill via bytes.ops single source (BytesZero inline FillChar for 0 else SpanFill for arbitrary) + Grow loop I-Cache bloat; zero-copy inline single source, no raw FillChar — L1 single source, red-line 1/2 gate: check_bytes_ops_source_contract.py
  if ACount = 0 then Exit;
  Grow(ACount);
  // perf: single source Fill via bytes.ops (BytesZero for 0, SpanFill for arbitrary) inline zero-copy, no raw FillChar — L1 single source, red-line 1/2; stability: Grow ensures capacity, sized FreeMemOf on Destroy keeps release not lost
  if AValue = 0 then
    nextpas.core.bytes.ops.BytesZero(FPtr + FLen, ACount)
  else
    nextpas.core.bytes.ops.SpanFill(TByteSpan.Create(FPtr + FLen, ACount), AValue);
  Inc(FLen, ACount);
end;

function TBytesBuilderImpl.WrittenSpan: TByteSpan; inline;
begin
  // zero-copy: returns view into internal buffer; caller must not use after builder free/mutation
  Result := TByteSpan.Create(FPtr, FLen);
end;

function TBytesBuilderImpl.ToBytes: TBytes;
begin
  // not inline per red-line 1/2: SetLength+BytesCopy batch I-Cache; single alloc copy for ownership (single BytesCopy inline zero-copy single source via bytes.ops INV-5); zero-copy hot path is WrittenSpan
  Result := nil;
  SetLength(Result, FLen);
  if FLen > 0 then
    nextpas.core.bytes.ops.BytesCopy(@Result[0], FPtr, FLen);
end;

procedure TBytesBuilderImpl.Clear;
begin
  FLen := 0;
end;

procedure TBytesBuilderImpl.Reserve(const AAdditional: SizeUInt);
begin
  Grow(AAdditional);
end;

procedure TBytesBuilderImpl.Truncate(const ANewLen: SizeUInt);
begin
  if ANewLen < FLen then
    FLen := ANewLen;
end;

end.
