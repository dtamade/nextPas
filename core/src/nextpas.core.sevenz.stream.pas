unit nextpas.core.sevenz.stream;

{**
 * nextpas.core.sevenz.stream - 7z 条目只读流单源
 *
 * 将 TSevenZEntryStream 从 reader 抽取为独立单元，供 reader 与
 * 未来复用点共享。持有 Extract 产出的 TBytes 引用（不二次拷贝），
 * Read/Seek/Size/Position 语义对齐 TBytesStream，Close 幂等，
 * 写入一律 ENotSupportedError。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.base,
  nextpas.core.io.intf;

type
  {** @desc 7z 条目只读流实现 *}
  TSevenZEntryStream = class(TInterfacedObject, IStream)
  private
    FData: TBytes;
    FPosition: SizeUInt;
    FClosed: Boolean;
    procedure EnsureOpen(const AOperation: string);
  public
    constructor Create(const AData: TBytes);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.exception;

constructor TSevenZEntryStream.Create(const AData: TBytes);
begin
  inherited Create;
  FData := AData;
  FPosition := 0;
  FClosed := False;
end;

procedure TSevenZEntryStream.EnsureOpen(const AOperation: string);
begin
  if FClosed then
    raise EIOError.Create('TSevenZEntryStream.' + AOperation + ': stream is closed');
end;

function TSevenZEntryStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  EnsureOpen('Read');
  if ACount = 0 then Exit(0);
  if FPosition >= SizeUInt(Length(FData)) then Exit(0);
  LAvailable := SizeUInt(Length(FData)) - FPosition;
  if ACount < LAvailable then Result := ACount else Result := LAvailable;
  Move(FData[FPosition], ABuf, Result);
  Inc(FPosition, Result);
end;

function TSevenZEntryStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  EnsureOpen('Write');
  Result := 0;
  raise ENotSupportedError.Create('TSevenZEntryStream.Write: entry stream is read-only');
end;

function TSevenZEntryStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
var
  LNewPos: Int64;
begin
  EnsureOpen('Seek');
  case AOrigin of
    soBeginning: LNewPos := AOffset;
    soCurrent: LNewPos := Int64(FPosition) + AOffset;
    else LNewPos := Int64(Length(FData)) + AOffset;
  end;
  if LNewPos < 0 then
    raise EArgumentError.Create('TSevenZEntryStream.Seek: negative position');
  FPosition := SizeUInt(LNewPos);
  Result := LNewPos;
end;

procedure TSevenZEntryStream.Close;
begin
  if not FClosed then
  begin
    FClosed := True;
    FData := nil;
    FPosition := 0;
  end;
end;

function TSevenZEntryStream.GetSize: Int64;
begin
  Result := Int64(Length(FData));
end;

function TSevenZEntryStream.GetPosition: Int64;
begin
  Result := Int64(FPosition);
end;

procedure TSevenZEntryStream.SetPosition(const AValue: Int64);
begin
  EnsureOpen('SetPosition');
  if AValue < 0 then
    raise EArgumentError.Create('TSevenZEntryStream.SetPosition: negative position');
  FPosition := SizeUInt(AValue);
end;

end.
