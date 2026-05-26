unit nextpas.core.io.memory;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.io.base,
  nextpas.core.io.intf;

function CreateBytesStream(const AInitialCapacity: SizeUInt = 256): IStream;
function CreateBytesStreamFrom(const AData: TBytes): IStream;

implementation

uses
  nextpas.core.errors;

type
  TBytesStream = class(TInterfacedObject, IReader, IWriter, IStream)
  private
    FData: TBytes;
    FSize: SizeUInt;
    FPosition: SizeUInt;
  public
    constructor Create(const AInitialCapacity: SizeUInt);
    constructor CreateFrom(const AData: TBytes);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
  end;

function CreateBytesStream(const AInitialCapacity: SizeUInt): IStream;
begin
  Result := TBytesStream.Create(AInitialCapacity);
end;

function CreateBytesStreamFrom(const AData: TBytes): IStream;
begin
  Result := TBytesStream.CreateFrom(AData);
end;

{ TBytesStream }

constructor TBytesStream.Create(const AInitialCapacity: SizeUInt);
begin
  inherited Create;
  SetLength(FData, AInitialCapacity);
  FSize := 0;
  FPosition := 0;
end;

constructor TBytesStream.CreateFrom(const AData: TBytes);
begin
  inherited Create;
  FData := Copy(AData);
  FSize := Length(AData);
  FPosition := 0;
end;

function TBytesStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  LAvailable := FSize - FPosition;
  if ACount < LAvailable then
    Result := ACount
  else
    Result := LAvailable;
  if Result > 0 then
  begin
    Move(FData[FPosition], ABuf, Result);
    Inc(FPosition, Result);
  end;
end;

function TBytesStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LNewSize: SizeUInt;
begin
  if ACount = 0 then
  begin
    Result := 0;
    Exit;
  end;
  LNewSize := FPosition + ACount;
  if LNewSize > SizeUInt(Length(FData)) then
  begin
    if LNewSize < SizeUInt(Length(FData)) * 2 then
      SetLength(FData, Length(FData) * 2)
    else
      SetLength(FData, LNewSize);
  end;
  Move(ABuf, FData[FPosition], ACount);
  Inc(FPosition, ACount);
  if FPosition > FSize then
    FSize := FPosition;
  Result := ACount;
end;

function TBytesStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
var
  LNewPos: Int64;
begin
  case AOrigin of
    soBeginning: LNewPos := AOffset;
    soCurrent: LNewPos := Int64(FPosition) + AOffset;
    soEnd: LNewPos := Int64(FSize) + AOffset;
  else
    raise EArgumentError.Create('TBytesStream.Seek: invalid origin');
  end;
  if LNewPos < 0 then
    raise EArgumentError.Create('TBytesStream.Seek: negative position');
  FPosition := SizeUInt(LNewPos);
  Result := LNewPos;
end;

procedure TBytesStream.Close;
begin
  FData := nil;
  FSize := 0;
  FPosition := 0;
end;

function TBytesStream.GetSize: Int64;
begin
  Result := Int64(FSize);
end;

function TBytesStream.GetPosition: Int64;
begin
  Result := Int64(FPosition);
end;

procedure TBytesStream.SetPosition(const AValue: Int64);
begin
  if AValue < 0 then
    raise EArgumentError.Create('TBytesStream.SetPosition: negative position');
  FPosition := SizeUInt(AValue);
end;

end.
