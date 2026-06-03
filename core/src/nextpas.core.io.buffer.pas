unit nextpas.core.io.buffer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.errors;

const
  DEFAULT_BUFFER_SIZE = 4096;

function CreateBufferedReader(const AInner: IReader; const ABufSize: SizeUInt = DEFAULT_BUFFER_SIZE): IReader;
function CreateBufferedWriter(const AInner: IWriter; const ABufSize: SizeUInt = DEFAULT_BUFFER_SIZE): IWriter;

implementation

procedure RaiseBufferedWriteFailure;
begin
  raise EIOError.Create('TBufferedWriter: write failed (zero progress)');
end;

type
  TBufferedReader = class(TInterfacedObject, IReader, IByteReader, IByteScanner)
  private
    FInner: IReader;
    FBuf: array of Byte;
    FBufPos: SizeUInt;
    FBufLen: SizeUInt;
    FLastByte: Byte;
    FHasLast: Boolean;
    FHasRead: Boolean;
  public
    constructor Create(const AInner: IReader; const ABufSize: SizeUInt);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function ReadByte: Byte;
    procedure UnreadByte;
  end;

  TBufferedWriter = class(TInterfacedObject, IWriter, IFlusher)
  private
    FInner: IWriter;
    FBuf: array of Byte;
    FBufPos: SizeUInt;
    FBufCap: SizeUInt;
    FError: Boolean;
    procedure FlushBuffer;
  public
    constructor Create(const AInner: IWriter; const ABufSize: SizeUInt);
    destructor Destroy; override;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    function HasError: Boolean; inline;
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
  if ABufSize = 0 then
    raise EArgumentError.Create('TBufferedReader: buffer size must be > 0');
  FInner := AInner;
  SetLength(FBuf, ABufSize);
  FBufPos := 0;
  FBufLen := 0;
  FHasLast := False;
  FHasRead := False;
end;

function TBufferedReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LDst: PByte;
  LRemaining, LFromBuf, LDirect: SizeUInt;
begin
  if ACount = 0 then
    Exit(0);

  LDst := @ABuf;
  LRemaining := ACount;
  Result := 0;

  if FHasLast then
  begin
    LDst^ := FLastByte;
    FHasLast := False;
    Inc(LDst);
    Dec(LRemaining);
    Inc(Result);
    if LRemaining = 0 then
      Exit;
  end;

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

function TBufferedReader.ReadByte: Byte;
var
  LN: SizeUInt;
begin
  if FHasLast then
  begin
    Result := FLastByte;
    FHasLast := False;
    Exit;
  end;
  LN := Read(Result, 1);
  if LN = 0 then
    raise EIOError.Create('TBufferedReader.ReadByte: EOF');
  FLastByte := Result;
  FHasRead := True;
end;

procedure TBufferedReader.UnreadByte;
begin
  if FHasLast then
    raise EInvalidOperationError.Create('TBufferedReader.UnreadByte: already unread');
  if not FHasRead then
    raise EInvalidOperationError.Create('TBufferedReader.UnreadByte: no prior ReadByte');
  FHasLast := True;
end;

{ TBufferedWriter }

constructor TBufferedWriter.Create(const AInner: IWriter; const ABufSize: SizeUInt);
begin
  inherited Create;
  if ABufSize = 0 then
    raise EArgumentError.Create('TBufferedWriter: buffer size must be > 0');
  FInner := AInner;
  SetLength(FBuf, ABufSize);
  FBufPos := 0;
  FBufCap := ABufSize;
  FError := False;
end;

destructor TBufferedWriter.Destroy;
begin
  if FBufPos > 0 then
    try
      FlushBuffer;
    except
      { Destructors cannot reliably surface flush failures. }
    end;
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
    begin
      if LTotal > 0 then
        Move(FBuf[LTotal], FBuf[0], FBufPos - LTotal);
      FBufPos := FBufPos - LTotal;
      FError := True;
      RaiseBufferedWriteFailure;
    end;
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
  Result := 0;

  while LRemaining > 0 do
  begin
    LSpace := FBufCap - FBufPos;
    if LRemaining <= LSpace then
    begin
      Move(LSrc^, FBuf[FBufPos], LRemaining);
      Inc(FBufPos, LRemaining);
      Inc(Result, LRemaining);
      Break;
    end;

    if LSpace > 0 then
    begin
      Move(LSrc^, FBuf[FBufPos], LSpace);
      Inc(LSrc, LSpace);
      Dec(LRemaining, LSpace);
      Inc(Result, LSpace);
      FBufPos := FBufCap;
    end;
    FlushBuffer;

    if LRemaining >= FBufCap then
    begin
      while LRemaining > 0 do
      begin
        LCopy := FInner.Write(LSrc^, LRemaining);
        if LCopy = 0 then
        begin
          FError := True;
          RaiseBufferedWriteFailure;
        end;
        Inc(LSrc, LCopy);
        Dec(LRemaining, LCopy);
        Inc(Result, LCopy);
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

function TBufferedWriter.HasError: Boolean;
begin
  Result := FError;
end;

end.
