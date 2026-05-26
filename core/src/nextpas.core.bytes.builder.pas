unit nextpas.core.bytes.builder;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.bytes.base,
  nextpas.core.bytes.intf;

function CreateByteBuilder(const AInitialCapacity: SizeUInt = 256): IByteBuilder;

implementation

type
  TByteBuilder = class(TInterfacedObject, IByteBuilder)
  private
    FData: TBytes;
    FSize: SizeUInt;
    procedure Grow(const ANeeded: SizeUInt);
  public
    constructor Create(const AInitialCapacity: SizeUInt);
    function GetSize: SizeUInt;
    procedure AppendByte(const AValue: Byte);
    procedure AppendBytes(const AData: PByte; const ACount: SizeUInt);
    procedure AppendUInt16(const AValue: Word; const AEndian: TEndian);
    procedure AppendUInt32(const AValue: LongWord; const AEndian: TEndian);
    procedure AppendUInt64(const AValue: QWord; const AEndian: TEndian);
    function ToBytes: TBytes;
    procedure Clear;
  end;

function CreateByteBuilder(const AInitialCapacity: SizeUInt): IByteBuilder;
begin
  Result := TByteBuilder.Create(AInitialCapacity);
end;

{ TByteBuilder }

constructor TByteBuilder.Create(const AInitialCapacity: SizeUInt);
begin
  inherited Create;
  SetLength(FData, AInitialCapacity);
  FSize := 0;
end;

procedure TByteBuilder.Grow(const ANeeded: SizeUInt);
var
  LNewCap: SizeUInt;
begin
  if FSize + ANeeded <= SizeUInt(Length(FData)) then
    Exit;
  LNewCap := SizeUInt(Length(FData));
  if LNewCap = 0 then
    LNewCap := 64;
  while LNewCap < FSize + ANeeded do
    LNewCap := LNewCap * 2;
  SetLength(FData, LNewCap);
end;

function TByteBuilder.GetSize: SizeUInt;
begin
  Result := FSize;
end;

procedure TByteBuilder.AppendByte(const AValue: Byte);
begin
  Grow(1);
  FData[FSize] := AValue;
  Inc(FSize);
end;

procedure TByteBuilder.AppendBytes(const AData: PByte; const ACount: SizeUInt);
begin
  if ACount = 0 then Exit;
  Grow(ACount);
  Move(AData^, FData[FSize], ACount);
  Inc(FSize, ACount);
end;

procedure TByteBuilder.AppendUInt16(const AValue: Word; const AEndian: TEndian);
begin
  Grow(2);
  if AEndian = enLittle then
  begin
    FData[FSize]     := Byte(AValue);
    FData[FSize + 1] := Byte(AValue shr 8);
  end
  else
  begin
    FData[FSize]     := Byte(AValue shr 8);
    FData[FSize + 1] := Byte(AValue);
  end;
  Inc(FSize, 2);
end;

procedure TByteBuilder.AppendUInt32(const AValue: LongWord; const AEndian: TEndian);
begin
  Grow(4);
  if AEndian = enLittle then
  begin
    FData[FSize]     := Byte(AValue);
    FData[FSize + 1] := Byte(AValue shr 8);
    FData[FSize + 2] := Byte(AValue shr 16);
    FData[FSize + 3] := Byte(AValue shr 24);
  end
  else
  begin
    FData[FSize]     := Byte(AValue shr 24);
    FData[FSize + 1] := Byte(AValue shr 16);
    FData[FSize + 2] := Byte(AValue shr 8);
    FData[FSize + 3] := Byte(AValue);
  end;
  Inc(FSize, 4);
end;

procedure TByteBuilder.AppendUInt64(const AValue: QWord; const AEndian: TEndian);
begin
  Grow(8);
  if AEndian = enLittle then
  begin
    FData[FSize]     := Byte(AValue);
    FData[FSize + 1] := Byte(AValue shr 8);
    FData[FSize + 2] := Byte(AValue shr 16);
    FData[FSize + 3] := Byte(AValue shr 24);
    FData[FSize + 4] := Byte(AValue shr 32);
    FData[FSize + 5] := Byte(AValue shr 40);
    FData[FSize + 6] := Byte(AValue shr 48);
    FData[FSize + 7] := Byte(AValue shr 56);
  end
  else
  begin
    FData[FSize]     := Byte(AValue shr 56);
    FData[FSize + 1] := Byte(AValue shr 48);
    FData[FSize + 2] := Byte(AValue shr 40);
    FData[FSize + 3] := Byte(AValue shr 32);
    FData[FSize + 4] := Byte(AValue shr 24);
    FData[FSize + 5] := Byte(AValue shr 16);
    FData[FSize + 6] := Byte(AValue shr 8);
    FData[FSize + 7] := Byte(AValue);
  end;
  Inc(FSize, 8);
end;

function TByteBuilder.ToBytes: TBytes;
begin
  Result := Copy(FData, 0, FSize);
end;

procedure TByteBuilder.Clear;
begin
  FSize := 0;
end;

end.
