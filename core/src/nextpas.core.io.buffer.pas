unit nextpas.core.io.buffer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf;

const
  DEFAULT_BUFFER_SIZE = 4096;

function CreateBufferedReader(const AInner: IReader; const ABufSize: SizeUInt = DEFAULT_BUFFER_SIZE): IReader;
function CreateBufferedWriter(const AInner: IWriter; const ABufSize: SizeUInt = DEFAULT_BUFFER_SIZE): IWriter;

implementation

type
  TBufferedReader = class(TInterfacedObject, IReader)
  private
    FInner: IReader;
    FBuf: array of Byte;
    FBufPos: SizeUInt;
    FBufLen: SizeUInt;
  public
    constructor Create(const AInner: IReader; const ABufSize: SizeUInt);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

  TBufferedWriter = class(TInterfacedObject, IWriter, IFlusher)
  private
    FInner: IWriter;
    FBuf: array of Byte;
    FBufPos: SizeUInt;
    FBufCap: SizeUInt;
    procedure FlushBuffer;
  public
    constructor Create(const AInner: IWriter; const ABufSize: SizeUInt);
    destructor Destroy; override;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
  end;

function CreateBufferedReader(const AInner: IReader; const ABufSize: SizeUInt): IReader;
begin
  Result := TBufferedReader.Create(AInner, ABufSize);
end;

function CreateBufferedWriter(const AInner: IWriter; const ABufSize: SizeUInt): IWriter;
begin
  Result := TBufferedWriter.Create(AInner, ABufSize);
end;

{ TBufferedReader }

constructor TBufferedReader.Create(const AInner: IReader; const ABufSize: SizeUInt);
begin
  inherited Create;
  FInner := AInner;
  SetLength(FBuf, ABufSize);
  FBufPos := 0;
  FBufLen := 0;
end;

function TBufferedReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LDst: PByte;
  LRemaining, LFromBuf, LDirect: SizeUInt;
begin
  LDst := @ABuf;
  LRemaining := ACount;
  Result := 0;

  // Serve from buffer first
  if FBufLen > FBufPos then
  begin
    LFromBuf := FBufLen - FBufPos;
    if LFromBuf > LRemaining then
      LFromBuf := LRemaining;
    Move(FBuf[FBufPos], LDst^, LFromBuf);
    Inc(FBufPos, LFromBuf);
    Inc(LDst, LFromBuf);
    Dec(LRemaining, LFromBuf);
    Inc(Result, LFromBuf);
  end;

  if LRemaining = 0 then
    Exit;

  // Large reads bypass buffer
  if LRemaining >= SizeUInt(Length(FBuf)) then
  begin
    LDirect := FInner.Read(LDst^, LRemaining);
    Inc(Result, LDirect);
    Exit;
  end;

  // Refill buffer
  FBufPos := 0;
  FBufLen := FInner.Read(FBuf[0], SizeUInt(Length(FBuf)));
  if FBufLen = 0 then
    Exit;

  LFromBuf := FBufLen;
  if LFromBuf > LRemaining then
    LFromBuf := LRemaining;
  Move(FBuf[0], LDst^, LFromBuf);
  FBufPos := LFromBuf;
  Inc(Result, LFromBuf);
end;

{ TBufferedWriter }

constructor TBufferedWriter.Create(const AInner: IWriter; const ABufSize: SizeUInt);
begin
  inherited Create;
  FInner := AInner;
  SetLength(FBuf, ABufSize);
  FBufPos := 0;
  FBufCap := ABufSize;
end;

destructor TBufferedWriter.Destroy;
begin
  if FBufPos > 0 then
    FlushBuffer;
  inherited;
end;

procedure TBufferedWriter.FlushBuffer;
var
  LWritten, LTotal: SizeUInt;
begin
  LTotal := 0;
  while LTotal < FBufPos do
  begin
    LWritten := FInner.Write(FBuf[LTotal], FBufPos - LTotal);
    if LWritten = 0 then
      Break;
    Inc(LTotal, LWritten);
  end;
  FBufPos := 0;
end;

function TBufferedWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LSrc: PByte;
  LRemaining, LSpace, LCopy: SizeUInt;
begin
  LSrc := @ABuf;
  LRemaining := ACount;
  Result := ACount;

  while LRemaining > 0 do
  begin
    LSpace := FBufCap - FBufPos;
    if LRemaining <= LSpace then
    begin
      Move(LSrc^, FBuf[FBufPos], LRemaining);
      Inc(FBufPos, LRemaining);
      Break;
    end;

    // Fill buffer and flush
    if LSpace > 0 then
    begin
      Move(LSrc^, FBuf[FBufPos], LSpace);
      Inc(LSrc, LSpace);
      Dec(LRemaining, LSpace);
      FBufPos := FBufCap;
    end;
    FlushBuffer;

    // Large writes bypass buffer
    if LRemaining >= FBufCap then
    begin
      while LRemaining > 0 do
      begin
        LCopy := FInner.Write(LSrc^, LRemaining);
        if LCopy = 0 then
          Exit;
        Inc(LSrc, LCopy);
        Dec(LRemaining, LCopy);
      end;
      Break;
    end;
  end;
end;

procedure TBufferedWriter.Flush;
begin
  if FBufPos > 0 then
    FlushBuffer;
end;

end.
