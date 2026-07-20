program test_csv_facade_surface;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.csv,
  nextpas.core.errors,
  nextpas.core.io.memory,
  nextpas.core.io.intf,
  nextpas.core.mem.default,
  nextpas.core.test;

var
  T: TTestSuite;

function BytesFromString(const AText: string): TBytes;
var
  LI: Integer;
begin
  SetLength(Result, Length(AText));
  for LI := 1 to Length(AText) do
    Result[LI - 1] := Byte(AText[LI]);
end;

procedure TestFacadeExposesCoreSurface;
var
  LReader: TCsvReader;
  LFields: TStringArray;
  LRows: TStringMatrix;
  LWriter: TCsvWriter;
  LError: TCsvError;
begin
  LReader := TCsvReader.Create('name,age' + #10 + 'Ada,37');
  Check(LReader.ReadRow(LFields), 'header row readable via facade');
  CheckEqual('name', LFields[0], 'header field 0');
  CheckEqual('age', LFields[1], 'header field 1');
  Check(LReader.ReadRow(LFields), 'data row readable via facade');
  CheckEqual('Ada', LFields[0], 'data field 0');
  CheckEqual('37', LFields[1], 'data field 1');
  CheckEqual(False, LReader.ReadRow(LFields), 'reader reaches end');
  CheckEqual(False, LReader.HasError, 'reader success state exposed');

  LRows := TCsvReader.Create('lang,year' + #10 + 'Pascal,1970').ReadAll;
  CheckEqual(Int64(2), Int64(Length(LRows)), 'matrix row count visible');
  CheckEqual('Pascal', LRows[1][0], 'matrix field value visible');

  LReader := TCsvReader.Create('"unterminated');
  Check(LReader.ReadRow(LFields), 'malformed row still surfaces a row call result');
  Check(LReader.HasError, 'reader error state visible');
  LError := LReader.Error;
  Check(LError.Line > 0, 'structured csv error visible through facade');
  Check(LReader.GetError <> '', 'string error visible through facade');

  LWriter := TCsvWriter.Create(';');
  LWriter.WriteField('left');
  LWriter.WriteField('right');
  LWriter.EndRow;
  LWriter.WriteRow(['Ada', '37']);
  Check(Pos('left;right', LWriter.ToString) = 1,
    'writer surface visible through facade');
end;

procedure TestFacadeExposesAllocatorSurface;
var
  LReader: TCsvReader;
  LRows: TStringMatrix;
begin
  LReader := TCsvReader.Create('x,y', ',', 0, False, #0, nil);
  Check(LReader.Allocator <> nil, 'reader allocator accessor visible');

  LRows := CsvParse('name,age' + #10 + 'Ada,37');
  CheckEqual(Int64(2), Int64(Length(LRows)), 'CsvParse row count visible');
  CheckEqual('37', LRows[1][1], 'CsvParse data value visible');

  LRows := CsvParseWith('lang;year' + #10 + 'Pascal;1970',
    DefaultAllocator, ';');
  CheckEqual(Int64(2), Int64(Length(LRows)),
    'CsvParseWith row count visible');
  CheckEqual('Pascal', LRows[1][0], 'CsvParseWith field value visible');
end;

type
  { Emits at most FChunk bytes per Read — forces multi-refill streaming. }
  TChunkedReader = class(TInterfacedObject, IReader)
  private
    FData: TBytes;
    FPos: SizeUInt;
    FChunk: SizeUInt;
  public
    constructor Create(const AData: TBytes; AChunk: SizeUInt);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TChunkedReader.Create(const AData: TBytes; AChunk: SizeUInt);
begin
  inherited Create;
  FData := AData;
  FPos := 0;
  if AChunk = 0 then
    FChunk := 1
  else
    FChunk := AChunk;
end;

function TChunkedReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvail, LTake: SizeUInt;
begin
  if FPos >= SizeUInt(Length(FData)) then
    Exit(0);
  LAvail := SizeUInt(Length(FData)) - FPos;
  LTake := ACount;
  if LTake > FChunk then
    LTake := FChunk;
  if LTake > LAvail then
    LTake := LAvail;
  if LTake = 0 then
    Exit(0);
  Move(FData[FPos], ABuf, LTake);
  Inc(FPos, LTake);
  Result := LTake;
end;

procedure TestFacadeExposesReaderSurface;
var
  LStream: IStream;
  LChunked: IReader;
  LReader: TCsvReader;
  LFields: TStringArray;
  LRows: TStringMatrix;
  LRaised: Boolean;
begin
  LStream := CreateBytesStreamFrom(BytesFromString(
    'name,age' + #10 + 'Ada,37' + #10));
  LReader := TCsvReader.Create(LStream as IReader);
  Check(LReader.ReadRow(LFields), 'IReader header row');
  CheckEqual('name', LFields[0], 'IReader header field 0');
  Check(LReader.ReadRow(LFields), 'IReader data row');
  CheckEqual('Ada', LFields[0], 'IReader data field 0');
  CheckEqual('37', LFields[1], 'IReader data field 1');
  CheckEqual(False, LReader.HasError, 'IReader parse clean');

  LStream := CreateBytesStreamFrom(BytesFromString(
    'a,b' + #10 + '1,2' + #10));
  LRows := TCsvReader.Create(LStream as IReader).ReadAll;
  CheckEqual(Int64(2), Int64(Length(LRows)), 'IReader ReadAll rows');
  CheckEqual('1', LRows[1][0], 'IReader ReadAll value');

  { Chunk size 1: every field and quote boundary spans refills. }
  LChunked := TChunkedReader.Create(BytesFromString(
    'id,note' + #10 + '1,"hello, ""world"""' + #10 + '2,plain' + #10), 1);
  LReader := TCsvReader.Create(LChunked);
  Check(LReader.ReadRow(LFields), 'chunked header');
  CheckEqual('id', LFields[0], 'chunked header 0');
  Check(LReader.ReadRow(LFields), 'chunked quoted row');
  CheckEqual('1', LFields[0], 'chunked id');
  CheckEqual('hello, "world"', LFields[1], 'chunked quoted field across refills');
  Check(LReader.ReadRow(LFields), 'chunked plain row');
  CheckEqual('plain', LFields[1], 'chunked plain field');
  CheckEqual(False, LReader.HasError, 'chunked stream clean');

  LRaised := False;
  try
    TCsvReader.Create(IReader(nil));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'nil IReader raises EArgumentError');
end;

begin
  T := TTestSuite.Create('nextpas.core.csv (facade surface)');
  T.Test('facade exposes core surface', @TestFacadeExposesCoreSurface);
  T.Test('facade exposes allocator surface',
    @TestFacadeExposesAllocatorSurface);
  T.Test('facade exposes IReader surface',
    @TestFacadeExposesReaderSurface);
  if not T.Run then Halt(1);
end.
