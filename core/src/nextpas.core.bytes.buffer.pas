unit nextpas.core.bytes.buffer;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.bytes.base,
  nextpas.core.bytes.intf;

function CreateByteBuffer(const ACapacity: SizeUInt = 256): IByteBuffer;
function CreateByteBufferFrom(const AData: TBytes): IByteBuffer;

implementation

type
  TByteBuffer = class(TInterfacedObject, IByteBuffer)
  private
    FData: TBytes;
    FSize: SizeUInt;
  public
    constructor Create(const ACapacity: SizeUInt);
    constructor CreateFrom(const AData: TBytes);
    function GetData: PByte;
    function GetSize: SizeUInt;
    function GetCapacity: SizeUInt;
    procedure SetSize(const ASize: SizeUInt);
    function Slice(const AOffset, ALength: SizeUInt): IByteBuffer;
    procedure CopyFrom(const ASrc: PByte; const ACount: SizeUInt);
  end;

function CreateByteBuffer(const ACapacity: SizeUInt): IByteBuffer;
begin
  Result := TByteBuffer.Create(ACapacity);
end;

function CreateByteBufferFrom(const AData: TBytes): IByteBuffer;
begin
  Result := TByteBuffer.CreateFrom(AData);
end;

{ TByteBuffer }

constructor TByteBuffer.Create(const ACapacity: SizeUInt);
begin
  inherited Create;
  SetLength(FData, ACapacity);
  FSize := 0;
end;

constructor TByteBuffer.CreateFrom(const AData: TBytes);
begin
  inherited Create;
  FData := Copy(AData);
  FSize := Length(AData);
end;

function TByteBuffer.GetData: PByte;
begin
  if FSize > 0 then
    Result := @FData[0]
  else
    Result := nil;
end;

function TByteBuffer.GetSize: SizeUInt;
begin
  Result := FSize;
end;

function TByteBuffer.GetCapacity: SizeUInt;
begin
  Result := Length(FData);
end;

procedure TByteBuffer.SetSize(const ASize: SizeUInt);
begin
  if ASize > SizeUInt(Length(FData)) then
    SetLength(FData, ASize);
  FSize := ASize;
end;

function TByteBuffer.Slice(const AOffset, ALength: SizeUInt): IByteBuffer;
var
  LResult: TByteBuffer;
begin
  if AOffset + ALength > FSize then
    raise ERangeError.Create('Slice out of bounds');
  LResult := TByteBuffer.Create(ALength);
  if ALength > 0 then
  begin
    Move(FData[AOffset], LResult.FData[0], ALength);
    LResult.FSize := ALength;
  end;
  Result := LResult;
end;

procedure TByteBuffer.CopyFrom(const ASrc: PByte; const ACount: SizeUInt);
begin
  if ACount > SizeUInt(Length(FData)) then
    SetLength(FData, ACount);
  if ACount > 0 then
    Move(ASrc^, FData[0], ACount);
  FSize := ACount;
end;

end.
