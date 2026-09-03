unit nextpas.core.io.slice;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf;

type
  {** @desc 零拷贝切片 IReader：tar/zip 统一单源，持有型流。 *}
  TIOSliceReader = class(TInterfacedObject, IReader)
  private
    FBase: PByte;
    FSize: SizeUInt;
    FPos: SizeUInt;
    FHold: TBytes; // 持有镜像防悬垂，Reader 释放后仍可读
  public
    constructor Create(ABase: PByte; ASize: SizeUInt); overload;
    constructor CreateWithHold(const AHold: TBytes; AOfs: SizeUInt; ASize: SizeUInt); overload;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

function CreateSliceReader(ABase: PByte; ASize: SizeUInt): IReader; inline;
function CreateSliceReaderWithHold(const AHold: TBytes; AOfs: SizeUInt; ASize: SizeUInt): IReader; inline;

implementation

uses
  nextpas.core.bytes.ops;

constructor TIOSliceReader.Create(ABase: PByte; ASize: SizeUInt);
begin
  inherited Create;
  FBase := ABase;
  FSize := ASize;
  FPos := 0;
  FHold := nil;
end;

constructor TIOSliceReader.CreateWithHold(const AHold: TBytes; AOfs: SizeUInt; ASize: SizeUInt);
var
  LAvail: SizeUInt;
begin
  inherited Create;
  FHold := AHold;
  FSize := ASize;
  FPos := 0;
  if Length(AHold) > 0 then
  begin
    LAvail := SizeUInt(Length(AHold));
    if AOfs > LAvail then
      FBase := nil
    else
    begin
      if AOfs + ASize > LAvail then
        FSize := LAvail - AOfs;
      if FSize > 0 then
        FBase := @AHold[AOfs]
      else
        FBase := nil;
    end;
  end
  else
    FBase := nil;
end;

function TIOSliceReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  Avail: SizeUInt;
  LCount: SizeUInt;
begin
  if FPos >= FSize then
    Exit(0);
  Avail := FSize - FPos;
  LCount := ACount;
  if LCount > Avail then
    LCount := Avail;
  if LCount > 0 then
  begin
    CopyMemory(@FBase[FPos], PByte(@ABuf), LCount);
    Inc(FPos, LCount);
  end;
  Result := LCount;
end;

function CreateSliceReader(ABase: PByte; ASize: SizeUInt): IReader; inline;
begin
  Result := TIOSliceReader.Create(ABase, ASize);
end;

function CreateSliceReaderWithHold(const AHold: TBytes; AOfs: SizeUInt; ASize: SizeUInt): IReader; inline;
begin
  Result := TIOSliceReader.CreateWithHold(AHold, AOfs, ASize);
end;

end.
