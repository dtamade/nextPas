unit nextpas.core.bytes.builder;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.mem.intf;

type
  TBytesBuilder = record
  private
    FPtr: PByte;
    FLen: SizeUInt;
    FCap: SizeUInt;
    FAllocator: IAllocator;
    procedure Grow(const ANeeded: SizeUInt);
  public
    procedure Init(const AAllocator: IAllocator; const AInitialCapacity: SizeUInt = BYTES_BUILDER_DEFAULT_CAPACITY);
    procedure InitDefault(const AInitialCapacity: SizeUInt = BYTES_BUILDER_DEFAULT_CAPACITY);
    procedure Done;
    function IsInitialized: Boolean; inline;

    procedure AppendByte(const AValue: Byte); inline;
    procedure AppendBytes(const AData: PByte; const ACount: SizeUInt);
    procedure AppendSpan(const ASpan: TByteSpan);
    procedure AppendUInt16LE(const AValue: UInt16);
    procedure AppendUInt16BE(const AValue: UInt16);
    procedure AppendUInt32LE(const AValue: UInt32);
    procedure AppendUInt32BE(const AValue: UInt32);
    procedure AppendUInt64LE(const AValue: UInt64);
    procedure AppendUInt64BE(const AValue: UInt64);
    procedure AppendFill(const AValue: Byte; const ACount: SizeUInt);

    function Len: SizeUInt; inline;
    function Cap: SizeUInt; inline;
    function WrittenSpan: TByteSpan; inline;

    function ToBytes: TBytes;
    procedure Clear;
    procedure Reserve(const AAdditional: SizeUInt);
    procedure Truncate(const ANewLen: SizeUInt);

    property Data: PByte read FPtr;
    property Length: SizeUInt read FLen;
    property Capacity: SizeUInt read FCap;
  end;

implementation

uses
  nextpas.core.mem;

{ TBytesBuilder }

procedure TBytesBuilder.Init(const AAllocator: IAllocator; const AInitialCapacity: SizeUInt);
begin
  FAllocator := AAllocator;
  if AInitialCapacity > 0 then
    FPtr := FAllocator.Allocate(AInitialCapacity)
  else
    FPtr := nil;
  FLen := 0;
  FCap := AInitialCapacity;
end;

procedure TBytesBuilder.InitDefault(const AInitialCapacity: SizeUInt);
begin
  Init(nextpas.core.mem.DefaultAllocator, AInitialCapacity);
end;

procedure TBytesBuilder.Done;
begin
  if FPtr <> nil then
  begin
    FAllocator.Deallocate(FPtr);
    FPtr := nil;
  end;
  FLen := 0;
  FCap := 0;
  FAllocator := nil;
end;

function TBytesBuilder.IsInitialized: Boolean;
begin
  Result := FAllocator <> nil;
end;

procedure TBytesBuilder.Grow(const ANeeded: SizeUInt);
var
  LNewCap: SizeUInt;
begin
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
  FPtr := FAllocator.Reallocate(FPtr, LNewCap);
  FCap := LNewCap;
end;

procedure TBytesBuilder.AppendByte(const AValue: Byte);
begin
  Grow(1);
  FPtr[FLen] := AValue;
  Inc(FLen);
end;

procedure TBytesBuilder.AppendBytes(const AData: PByte; const ACount: SizeUInt);
begin
  if ACount = 0 then Exit;
  Grow(ACount);
  Move(AData^, FPtr[FLen], ACount);
  Inc(FLen, ACount);
end;

procedure TBytesBuilder.AppendSpan(const ASpan: TByteSpan);
begin
  AppendBytes(ASpan.Data, ASpan.Len);
end;

procedure TBytesBuilder.AppendUInt16LE(const AValue: UInt16);
begin
  Grow(2);
  FPtr[FLen]     := Byte(AValue);
  FPtr[FLen + 1] := Byte(AValue shr 8);
  Inc(FLen, 2);
end;

procedure TBytesBuilder.AppendUInt16BE(const AValue: UInt16);
begin
  Grow(2);
  FPtr[FLen]     := Byte(AValue shr 8);
  FPtr[FLen + 1] := Byte(AValue);
  Inc(FLen, 2);
end;

procedure TBytesBuilder.AppendUInt32LE(const AValue: UInt32);
begin
  Grow(4);
  FPtr[FLen]     := Byte(AValue);
  FPtr[FLen + 1] := Byte(AValue shr 8);
  FPtr[FLen + 2] := Byte(AValue shr 16);
  FPtr[FLen + 3] := Byte(AValue shr 24);
  Inc(FLen, 4);
end;

procedure TBytesBuilder.AppendUInt32BE(const AValue: UInt32);
begin
  Grow(4);
  FPtr[FLen]     := Byte(AValue shr 24);
  FPtr[FLen + 1] := Byte(AValue shr 16);
  FPtr[FLen + 2] := Byte(AValue shr 8);
  FPtr[FLen + 3] := Byte(AValue);
  Inc(FLen, 4);
end;

procedure TBytesBuilder.AppendUInt64LE(const AValue: UInt64);
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

procedure TBytesBuilder.AppendUInt64BE(const AValue: UInt64);
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

procedure TBytesBuilder.AppendFill(const AValue: Byte; const ACount: SizeUInt);
begin
  if ACount = 0 then Exit;
  Grow(ACount);
  FillChar(FPtr[FLen], ACount, AValue);
  Inc(FLen, ACount);
end;

function TBytesBuilder.Len: SizeUInt;
begin
  Result := FLen;
end;

function TBytesBuilder.Cap: SizeUInt;
begin
  Result := FCap;
end;

function TBytesBuilder.WrittenSpan: TByteSpan;
begin
  Result := TByteSpan.Create(FPtr, FLen);
end;

function TBytesBuilder.ToBytes: TBytes;
begin
  SetLength(Result, FLen);
  if FLen > 0 then
    Move(FPtr^, Result[0], FLen);
end;

procedure TBytesBuilder.Clear;
begin
  FLen := 0;
end;

procedure TBytesBuilder.Reserve(const AAdditional: SizeUInt);
begin
  Grow(AAdditional);
end;

procedure TBytesBuilder.Truncate(const ANewLen: SizeUInt);
begin
  if ANewLen < FLen then
    FLen := ANewLen;
end;

end.
