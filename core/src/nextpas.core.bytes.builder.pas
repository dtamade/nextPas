unit nextpas.core.bytes.builder;

{$I nextpas.core.settings.inc}

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
    procedure AppendBytes(const AData: PByte; const ACount: SizeUInt); inline;
    procedure AppendSpan(const ASpan: TByteSpan); inline;
    procedure AppendUInt16LE(const AValue: UInt16); inline;
    procedure AppendUInt16BE(const AValue: UInt16); inline;
    procedure AppendUInt32LE(const AValue: UInt32); inline;
    procedure AppendUInt32BE(const AValue: UInt32); inline;
    procedure AppendUInt64LE(const AValue: UInt64); inline;
    procedure AppendUInt64BE(const AValue: UInt64); inline;
    procedure AppendFill(const AValue: Byte; const ACount: SizeUInt); inline;

    { perf: WrittenSpan is zero-copy view into builder buffer (no allocation);
      ToBytes copies with one allocation for ownership transfer. }
    function WrittenSpan: TByteSpan; inline;
    function ToBytes: TBytes; inline;

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
  nextpas.core.mem;

type
  TBytesBuilderImpl = class(TRefCountedObject, IBytesBuilder)
  private
    FPtr: PByte;
    FLen: SizeUInt;
    FCap: SizeUInt;
    FAllocator: TMemAllocator;
    procedure Grow(const ANeeded: SizeUInt); inline;
  public
    constructor Create(const AAllocator: TMemAllocator; const AInitialCapacity: SizeUInt);
    destructor Destroy; override;

    function GetLength: SizeUInt;
    function GetCapacity: SizeUInt;
    function GetData: PByte;

    procedure AppendByte(const AValue: Byte); inline;
    procedure AppendBytes(const AData: PByte; const ACount: SizeUInt); inline;
    procedure AppendSpan(const ASpan: TByteSpan); inline;
    procedure AppendUInt16LE(const AValue: UInt16); inline;
    procedure AppendUInt16BE(const AValue: UInt16); inline;
    procedure AppendUInt32LE(const AValue: UInt32); inline;
    procedure AppendUInt32BE(const AValue: UInt32); inline;
    procedure AppendUInt64LE(const AValue: UInt64); inline;
    procedure AppendUInt64BE(const AValue: UInt64); inline;
    procedure AppendFill(const AValue: Byte; const ACount: SizeUInt); inline;

    function WrittenSpan: TByteSpan; inline;
    function ToBytes: TBytes; inline;

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

procedure TBytesBuilderImpl.Grow(const ANeeded: SizeUInt); inline;
var
  LNewCap: SizeUInt;
begin
  // perf: inline hot path — enables Append* to inline Grow+Move/FillChar without call overhead; single ReallocMemOf
  if FLen + ANeeded <= FCap then
    Exit;
  LNewCap := FCap;
  if LNewCap < BYTES_BUILDER_MIN_GROW then
    LNewCap := BYTES_BUILDER_MIN_GROW;
  while LNewCap < FLen + ANeeded do
  begin
    if LNewCap <= High(SizeUInt) div 2 then
      LNewCap := LNewCap * 2
    else
    begin
      LNewCap := FLen + ANeeded;
      Break;
    end;
  end;
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

procedure TBytesBuilderImpl.AppendBytes(const AData: PByte; const ACount: SizeUInt); inline;
begin
  if ACount = 0 then Exit;
  Grow(ACount);
  Move(AData^, FPtr[FLen], ACount);
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

procedure TBytesBuilderImpl.AppendFill(const AValue: Byte; const ACount: SizeUInt); inline;
begin
  if ACount = 0 then Exit;
  Grow(ACount);
  FillChar(FPtr[FLen], ACount, AValue);
  Inc(FLen, ACount);
end;

function TBytesBuilderImpl.WrittenSpan: TByteSpan; inline;
begin
  // zero-copy: returns view into internal buffer; caller must not use after builder free/mutation
  Result := TByteSpan.Create(FPtr, FLen);
end;

function TBytesBuilderImpl.ToBytes: TBytes; inline;
begin
  // perf: single allocation copy for ownership; for zero-copy hot path use WrittenSpan
  Result := nil;
  SetLength(Result, FLen);
  if FLen > 0 then
    Move(FPtr^, Result[0], FLen);
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
