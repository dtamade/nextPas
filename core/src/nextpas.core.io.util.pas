unit nextpas.core.io.util;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.io.intf;

function IoCopy(const ADst: IWriter; const ASrc: IReader): Int64;
function IoCopyN(const ADst: IWriter; const ASrc: IReader; const AN: Int64): Int64;
function IoReadAll(const ASrc: IReader): TBytes;
procedure IoReadFull(const ASrc: IReader; var ABuf; const ACount: SizeUInt);
function IoLimitReader(const AInner: IReader; const ALimit: Int64): IReader;
function IoTeeReader(const AInner: IReader; const AWriter: IWriter): IReader;
function IoMultiReader(const AReaders: array of IReader): IReader;
function IoMultiWriter(const AWriters: array of IWriter): IWriter;
function IoNopCloser(const AInner: IReader): IReadCloser;
function IoDiscard: IWriter;
function IoNullReader: IReader;

function IoCopyBuffer(const ADst: IWriter; const ASrc: IReader; var ABuf; const ABufSize: SizeUInt): Int64;
procedure IoReadAtLeast(const ASrc: IReader; var ABuf; const ACount, AMin: SizeUInt);
function IoWriteString(const ADst: IWriter; const AStr: string): SizeUInt;
function IoSectionReader(const AInner: IReaderAt; const AOffset, ALimit: Int64): IReader;

implementation

uses
  nextpas.core.errors;

const
  COPY_BUF_SIZE = 32768;

{ IoCopy }

function IoCopy(const ADst: IWriter; const ASrc: IReader): Int64;
var
  LBuf: array[0..COPY_BUF_SIZE - 1] of Byte;
  LRead, LWritten, LTotal: SizeUInt;
  LReaderFrom: IReaderFrom;
  LWriterTo: IWriterTo;
begin
  if Supports(ASrc, IWriterTo, LWriterTo) then
    Exit(LWriterTo.WriteTo(ADst));
  if Supports(ADst, IReaderFrom, LReaderFrom) then
    Exit(LReaderFrom.ReadFrom(ASrc));
  Result := 0;
  repeat
    LRead := ASrc.Read(LBuf[0], COPY_BUF_SIZE);
    if LRead = 0 then
      Break;
    LTotal := 0;
    while LTotal < LRead do
    begin
      LWritten := ADst.Write(LBuf[LTotal], LRead - LTotal);
      if LWritten = 0 then
        raise EIOError.Create('IoCopy: write returned 0');
      Inc(LTotal, LWritten);
    end;
    Inc(Result, Int64(LRead));
  until False;
end;

{ IoCopyN }

function IoCopyN(const ADst: IWriter; const ASrc: IReader; const AN: Int64): Int64;
var
  LBuf: array[0..COPY_BUF_SIZE - 1] of Byte;
  LRemaining: Int64;
  LToRead, LRead, LWritten, LTotal: SizeUInt;
begin
  Result := 0;
  LRemaining := AN;
  while LRemaining > 0 do
  begin
    if LRemaining > COPY_BUF_SIZE then
      LToRead := COPY_BUF_SIZE
    else
      LToRead := SizeUInt(LRemaining);
    LRead := ASrc.Read(LBuf[0], LToRead);
    if LRead = 0 then
      Break;
    LTotal := 0;
    while LTotal < LRead do
    begin
      LWritten := ADst.Write(LBuf[LTotal], LRead - LTotal);
      if LWritten = 0 then
        raise EIOError.Create('IoCopyN: write returned 0');
      Inc(LTotal, LWritten);
    end;
    Inc(Result, Int64(LRead));
    Dec(LRemaining, Int64(LRead));
  end;
end;

{ IoReadAll }

function IoReadAll(const ASrc: IReader): TBytes;
var
  LBuf: array[0..COPY_BUF_SIZE - 1] of Byte;
  LRead, LSize, LCap: SizeUInt;
begin
  LSize := 0;
  LCap := 0;
  Result := nil;
  repeat
    LRead := ASrc.Read(LBuf[0], COPY_BUF_SIZE);
    if LRead = 0 then
      Break;
    if LSize + LRead > LCap then
    begin
      if LCap = 0 then
        LCap := COPY_BUF_SIZE
      else
        LCap := LCap * 2;
      if LCap < LSize + LRead then
        LCap := LSize + LRead;
      SetLength(Result, LCap);
    end;
    Move(LBuf[0], Result[LSize], LRead);
    Inc(LSize, LRead);
  until False;
  SetLength(Result, LSize);
end;

{ IoReadFull }

procedure IoReadFull(const ASrc: IReader; var ABuf; const ACount: SizeUInt);
var
  LDst: PByte;
  LRemaining, LRead: SizeUInt;
begin
  LDst := @ABuf;
  LRemaining := ACount;
  while LRemaining > 0 do
  begin
    LRead := ASrc.Read(LDst^, LRemaining);
    if LRead = 0 then
      raise EIOError.Create('IoReadFull: unexpected EOF');
    Inc(LDst, LRead);
    Dec(LRemaining, LRead);
  end;
end;

{ TLimitReader }

type
  TLimitReader = class(TInterfacedObject, IReader)
  private
    FInner: IReader;
    FRemaining: Int64;
  public
    constructor Create(const AInner: IReader; const ALimit: Int64);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TLimitReader.Create(const AInner: IReader; const ALimit: Int64);
begin
  inherited Create;
  FInner := AInner;
  FRemaining := ALimit;
end;

function TLimitReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LToRead: SizeUInt;
begin
  if FRemaining <= 0 then
    Exit(0);
  if Int64(ACount) > FRemaining then
    LToRead := SizeUInt(FRemaining)
  else
    LToRead := ACount;
  Result := FInner.Read(ABuf, LToRead);
  Dec(FRemaining, Int64(Result));
end;

function IoLimitReader(const AInner: IReader; const ALimit: Int64): IReader;
begin
  Result := TLimitReader.Create(AInner, ALimit);
end;

{ TTeeReader }

type
  TTeeReader = class(TInterfacedObject, IReader)
  private
    FInner: IReader;
    FWriter: IWriter;
  public
    constructor Create(const AInner: IReader; const AWriter: IWriter);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TTeeReader.Create(const AInner: IReader; const AWriter: IWriter);
begin
  inherited Create;
  FInner := AInner;
  FWriter := AWriter;
end;

function TTeeReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FInner.Read(ABuf, ACount);
  if Result > 0 then
    FWriter.Write(ABuf, Result);
end;

function IoTeeReader(const AInner: IReader; const AWriter: IWriter): IReader;
begin
  Result := TTeeReader.Create(AInner, AWriter);
end;

{ TMultiReader }

type
  TMultiReader = class(TInterfacedObject, IReader)
  private
    FReaders: array of IReader;
    FIndex: Integer;
  public
    constructor Create(const AReaders: array of IReader);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TMultiReader.Create(const AReaders: array of IReader);
var
  LI: Integer;
begin
  inherited Create;
  SetLength(FReaders, Length(AReaders));
  for LI := 0 to High(AReaders) do
    FReaders[LI] := AReaders[LI];
  FIndex := 0;
end;

function TMultiReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  while FIndex <= High(FReaders) do
  begin
    Result := FReaders[FIndex].Read(ABuf, ACount);
    if Result > 0 then
      Exit;
    Inc(FIndex);
  end;
  Result := 0;
end;

function IoMultiReader(const AReaders: array of IReader): IReader;
begin
  Result := TMultiReader.Create(AReaders);
end;

{ TMultiWriter }

type
  TMultiWriter = class(TInterfacedObject, IWriter)
  private
    FWriters: array of IWriter;
  public
    constructor Create(const AWriters: array of IWriter);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TMultiWriter.Create(const AWriters: array of IWriter);
var
  LI: Integer;
begin
  inherited Create;
  SetLength(FWriters, Length(AWriters));
  for LI := 0 to High(AWriters) do
    FWriters[LI] := AWriters[LI];
end;

function TMultiWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LI: Integer;
begin
  Result := ACount;
  for LI := 0 to High(FWriters) do
    FWriters[LI].Write(ABuf, ACount);
end;

function IoMultiWriter(const AWriters: array of IWriter): IWriter;
begin
  Result := TMultiWriter.Create(AWriters);
end;

{ TNopCloser }

type
  TNopCloser = class(TInterfacedObject, IReader, IReadCloser)
  private
    FInner: IReader;
  public
    constructor Create(const AInner: IReader);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
  end;

constructor TNopCloser.Create(const AInner: IReader);
begin
  inherited Create;
  FInner := AInner;
end;

function TNopCloser.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FInner.Read(ABuf, ACount);
end;

procedure TNopCloser.Close;
begin
end;

function IoNopCloser(const AInner: IReader): IReadCloser;
begin
  Result := TNopCloser.Create(AInner);
end;

{ TDiscardWriter }

type
  TDiscardWriter = class(TInterfacedObject, IWriter)
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

function TDiscardWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := ACount;
end;

function IoDiscard: IWriter;
begin
  Result := TDiscardWriter.Create;
end;

{ TNullReader }

type
  TNullReader = class(TInterfacedObject, IReader)
  public
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

function TNullReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;
end;

function IoNullReader: IReader;
begin
  Result := TNullReader.Create;
end;

{ IoCopyBuffer }

function IoCopyBuffer(const ADst: IWriter; const ASrc: IReader; var ABuf; const ABufSize: SizeUInt): Int64;
var
  LBuf: PByte;
  LRead, LWritten, LTotal: SizeUInt;
begin
  Result := 0;
  LBuf := @ABuf;
  repeat
    LRead := ASrc.Read(LBuf^, ABufSize);
    if LRead = 0 then
      Break;
    LTotal := 0;
    while LTotal < LRead do
    begin
      LWritten := ADst.Write(LBuf[LTotal], LRead - LTotal);
      if LWritten = 0 then
        raise EIOError.Create('IoCopyBuffer: write returned 0');
      Inc(LTotal, LWritten);
    end;
    Inc(Result, Int64(LRead));
  until False;
end;

{ IoReadAtLeast }

procedure IoReadAtLeast(const ASrc: IReader; var ABuf; const ACount, AMin: SizeUInt);
var
  LDst: PByte;
  LTotal, LRead: SizeUInt;
begin
  if AMin > ACount then
    raise EArgumentError.Create('IoReadAtLeast: AMin > ACount');
  LDst := @ABuf;
  LTotal := 0;
  while LTotal < AMin do
  begin
    LRead := ASrc.Read(LDst[LTotal], ACount - LTotal);
    if LRead = 0 then
      raise EIOError.Create('IoReadAtLeast: unexpected EOF');
    Inc(LTotal, LRead);
  end;
end;

{ IoWriteString }

function IoWriteString(const ADst: IWriter; const AStr: string): SizeUInt;
begin
  if Length(AStr) = 0 then
    Exit(0);
  Result := ADst.Write(AStr[1], SizeUInt(Length(AStr)));
end;

{ TSectionReader }

type
  TSectionReader = class(TInterfacedObject, IReader)
  private
    FInner: IReaderAt;
    FOffset: Int64;
    FLimit: Int64;
    FPos: Int64;
  public
    constructor Create(const AInner: IReaderAt; const AOffset, ALimit: Int64);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TSectionReader.Create(const AInner: IReaderAt; const AOffset, ALimit: Int64);
begin
  inherited Create;
  FInner := AInner;
  FOffset := AOffset;
  FLimit := ALimit;
  FPos := 0;
end;

function TSectionReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRemaining: Int64;
  LToRead: SizeUInt;
begin
  LRemaining := FLimit - FPos;
  if LRemaining <= 0 then
    Exit(0);
  if Int64(ACount) > LRemaining then
    LToRead := SizeUInt(LRemaining)
  else
    LToRead := ACount;
  Result := FInner.ReadAt(ABuf, LToRead, FOffset + FPos);
  Inc(FPos, Int64(Result));
end;

function IoSectionReader(const AInner: IReaderAt; const AOffset, ALimit: Int64): IReader;
begin
  Result := TSectionReader.Create(AInner, AOffset, ALimit);
end;

end.