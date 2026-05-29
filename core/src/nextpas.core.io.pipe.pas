unit nextpas.core.io.pipe;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf;

type
  IPipeReader = interface(IReader)
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000050}']
    procedure Close;
  end;

  IPipeWriter = interface(IWriter)
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000051}']
    procedure Close;
  end;

procedure CreatePipe(out AReader: IPipeReader; out AWriter: IPipeWriter);

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.sync;

const
  PIPE_BUF_SIZE = 4096;

type
  IPipeState = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000052}']
    function DoRead(var ABuf; const ACount: SizeUInt): SizeUInt;
    function DoWrite(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure CloseWriter;
    procedure CloseReader;
  end;

  TPipeState = class(TInterfacedObject, IPipeState)
  private
    FBuf: array of Byte;
    FReadPos: SizeUInt;
    FWritePos: SizeUInt;
    FCount: SizeUInt;
    FCap: SizeUInt;
    FMutex: IMutex;
    FNotEmpty: ICondVar;
    FNotFull: ICondVar;
    FWriterClosed: Boolean;
    FReaderClosed: Boolean;
  public
    constructor Create;
    function DoRead(var ABuf; const ACount: SizeUInt): SizeUInt;
    function DoWrite(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure CloseWriter;
    procedure CloseReader;
  end;

  TPipeReader = class(TInterfacedObject, IReader, IPipeReader)
  private
    FState: IPipeState;
  public
    constructor Create(const AState: IPipeState);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
  end;

  TPipeWriter = class(TInterfacedObject, IWriter, IPipeWriter)
  private
    FState: IPipeState;
  public
    constructor Create(const AState: IPipeState);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
  end;

procedure CreatePipe(out AReader: IPipeReader; out AWriter: IPipeWriter);
var
  LState: IPipeState;
begin
  LState := TPipeState.Create;
  AReader := TPipeReader.Create(LState);
  AWriter := TPipeWriter.Create(LState);
end;

{ TPipeState }

constructor TPipeState.Create;
begin
  inherited;
  FCap := PIPE_BUF_SIZE;
  SetLength(FBuf, FCap);
  FReadPos := 0;
  FWritePos := 0;
  FCount := 0;
  FWriterClosed := False;
  FReaderClosed := False;
  FMutex := nextpas.core.sync.Mutex;
  FNotEmpty := nextpas.core.sync.CondVar;
  FNotFull := nextpas.core.sync.CondVar;
end;

function TPipeState.DoRead(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LDst: PByte;
  LToRead, LChunk: SizeUInt;
begin
  LDst := @ABuf;
  FMutex.Acquire;
  try
    while (FCount = 0) and (not FWriterClosed) do
      FNotEmpty.Wait(FMutex);
    if (FCount = 0) and FWriterClosed then
      Exit(0);
    if ACount < FCount then
      LToRead := ACount
    else
      LToRead := FCount;
    Result := LToRead;
    while LToRead > 0 do
    begin
      LChunk := FCap - FReadPos;
      if LChunk > LToRead then
        LChunk := LToRead;
      Move(FBuf[FReadPos], LDst^, LChunk);
      Inc(LDst, LChunk);
      FReadPos := (FReadPos + LChunk) mod FCap;
      Dec(FCount, LChunk);
      Dec(LToRead, LChunk);
    end;
    FNotFull.Broadcast;
  finally
    FMutex.Release;
  end;
end;

function TPipeState.DoWrite(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LSrc: PByte;
  LRemaining, LSpace, LChunk: SizeUInt;
begin
  LSrc := @ABuf;
  LRemaining := ACount;
  Result := 0;
  FMutex.Acquire;
  try
    while LRemaining > 0 do
    begin
      while (FCount = FCap) and (not FReaderClosed) do
        FNotFull.Wait(FMutex);
      if FReaderClosed then
        raise EIOError.Create('write to closed pipe');
      LSpace := FCap - FCount;
      if LRemaining < LSpace then
        LSpace := LRemaining;
      LChunk := LSpace;
      while LChunk > 0 do
      begin
        LSpace := FCap - FWritePos;
        if LSpace > LChunk then
          LSpace := LChunk;
        Move(LSrc^, FBuf[FWritePos], LSpace);
        Inc(LSrc, LSpace);
        FWritePos := (FWritePos + LSpace) mod FCap;
        Inc(FCount, LSpace);
        Dec(LChunk, LSpace);
        Dec(LRemaining, LSpace);
        Inc(Result, LSpace);
      end;
      FNotEmpty.Broadcast;
    end;
  finally
    FMutex.Release;
  end;
end;

procedure TPipeState.CloseWriter;
begin
  FMutex.Acquire;
  try
    FWriterClosed := True;
    FNotEmpty.Broadcast;
  finally
    FMutex.Release;
  end;
end;

procedure TPipeState.CloseReader;
begin
  FMutex.Acquire;
  try
    FReaderClosed := True;
    FNotFull.Broadcast;
  finally
    FMutex.Release;
  end;
end;

{ TPipeReader }

constructor TPipeReader.Create(const AState: IPipeState);
begin
  inherited Create;
  FState := AState;
end;

function TPipeReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FState.DoRead(ABuf, ACount);
end;

procedure TPipeReader.Close;
begin
  FState.CloseReader;
end;

{ TPipeWriter }

constructor TPipeWriter.Create(const AState: IPipeState);
begin
  inherited Create;
  FState := AState;
end;

function TPipeWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FState.DoWrite(ABuf, ACount);
end;

procedure TPipeWriter.Close;
begin
  FState.CloseWriter;
end;

end.
