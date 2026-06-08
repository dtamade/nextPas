unit nextpas.core.io.memory;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.base,
  nextpas.core.io.intf;

function CreateBytesStream(const AInitialCapacity: SizeUInt = 256): IStream;
function CreateBytesStreamFrom(const AData: TBytes): IStream;

implementation

uses
  nextpas.core.errors;

type
  TBytesStream = class(TInterfacedObject, IReader, IWriter, IStream, IReaderAt, IWriterAt, IByteReader, IByteWriter, IStringWriter)
  private
    FData: TBytes;
    FSize: SizeUInt;
    FPosition: SizeUInt;
    FClosed: Boolean;
    procedure EnsureOpen(const AOperation: string);
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
    function ReadAt(var ABuf; const ACount: SizeUInt; const AOffset: Int64): SizeUInt;
    function WriteAt(const ABuf; const ACount: SizeUInt; const AOffset: Int64): SizeUInt;
    function ReadByte: Byte;
    procedure WriteByte(const AValue: Byte);
    function WriteString(const AStr: string): SizeUInt;
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
  FClosed := False;
end;

constructor TBytesStream.CreateFrom(const AData: TBytes);
begin
  inherited Create;
  FData := Copy(AData);
  FSize := Length(AData);
  FPosition := 0;
  FClosed := False;
end;

procedure TBytesStream.EnsureOpen(const AOperation: string);
begin
  if FClosed then
    raise EIOError.Create('TBytesStream.' + AOperation + ': stream is closed');
end;

function TBytesStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  if ACount = 0 then Exit(0);
  EnsureOpen('Read');
  if FPosition >= FSize then Exit(0);
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
  EnsureOpen('Write');
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
  EnsureOpen('Seek');
  case AOrigin of
    soBeginning: LNewPos := AOffset;
    soCurrent: LNewPos := Int64(FPosition) + AOffset;
    soEnd: LNewPos := Int64(FSize) + AOffset;
  end;
  if LNewPos < 0 then
    raise EArgumentError.Create('TBytesStream.Seek: negative position');
  FPosition := SizeUInt(LNewPos);
  Result := LNewPos;
end;

procedure TBytesStream.Close;
begin
  if not FClosed then
  begin
    FClosed := True;
    FData := nil;
    FSize := 0;
    FPosition := 0;
  end;
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
  EnsureOpen('SetPosition');
  if AValue < 0 then
    raise EArgumentError.Create('TBytesStream.SetPosition: negative position');
  FPosition := SizeUInt(AValue);
end;

function TBytesStream.ReadAt(var ABuf; const ACount: SizeUInt; const AOffset: Int64): SizeUInt;
var
  LAvail: SizeUInt;
begin
  EnsureOpen('ReadAt');
  if AOffset < 0 then
    raise EArgumentError.Create('TBytesStream.ReadAt: negative offset');
  if SizeUInt(AOffset) >= FSize then
    Exit(0);
  LAvail := FSize - SizeUInt(AOffset);
  if ACount < LAvail then
    Result := ACount
  else
    Result := LAvail;
  if Result > 0 then
    Move(FData[SizeUInt(AOffset)], ABuf, Result);
end;

function TBytesStream.WriteAt(const ABuf; const ACount: SizeUInt; const AOffset: Int64): SizeUInt;
var
  LEnd: SizeUInt;
begin
  EnsureOpen('WriteAt');
  if AOffset < 0 then
    raise EArgumentError.Create('TBytesStream.WriteAt: negative offset');
  if ACount = 0 then
    Exit(0);
  LEnd := SizeUInt(AOffset) + ACount;
  if LEnd > SizeUInt(Length(FData)) then
  begin
    if LEnd < SizeUInt(Length(FData)) * 2 then
      SetLength(FData, Length(FData) * 2)
    else
      SetLength(FData, LEnd);
  end;
  Move(ABuf, FData[SizeUInt(AOffset)], ACount);
  if LEnd > FSize then
    FSize := LEnd;
  Result := ACount;
end;

function TBytesStream.ReadByte: Byte;
begin
  EnsureOpen('ReadByte');
  if FPosition >= FSize then
    raise EIOError.Create('TBytesStream.ReadByte: EOF');
  Result := FData[FPosition];
  Inc(FPosition);
end;

procedure TBytesStream.WriteByte(const AValue: Byte);
begin
  Write(AValue, 1);
end;

function TBytesStream.WriteString(const AStr: string): SizeUInt;
begin
  EnsureOpen('WriteString');
  if Length(AStr) = 0 then
    Exit(0);
  Result := Write(AStr[1], SizeUInt(Length(AStr)));
end;

end.
