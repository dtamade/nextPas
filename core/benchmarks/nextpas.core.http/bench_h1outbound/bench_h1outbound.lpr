program bench_h1outbound;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.http.impl.h1.outbound;

type
  TFixedMemoryWriter = class(TInterfacedObject, IWriter)
  private
    FBuffer: array[0..4095] of Byte;
    FSize: SizeUInt;
  public
    procedure Reset;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Size: SizeUInt;
  end;

  TFixedChunkRuntime = class(TInterfacedObject, ITcpStreamRuntime)
  private
    FChunkSize: SizeUInt;
    FBytesAccepted: SizeUInt;
  public
    constructor Create(const AChunkSize: SizeUInt);
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;
    procedure Reset;
    function BytesAccepted: SizeUInt;
  end;

var
  B: TBenchRunner;
  GPayload: array[0..1023] of Byte;
  GBytesDrained: SizeUInt;

procedure TFixedMemoryWriter.Reset;
begin
  FSize := 0;
end;

function TFixedMemoryWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  LAvailable := SizeUInt(Length(FBuffer)) - FSize;
  Result := ACount;
  if Result > LAvailable then
    Result := LAvailable;
  if Result > 0 then
  begin
    Move(ABuf, FBuffer[FSize], Result);
    Inc(FSize, Result);
  end;
end;

function TFixedMemoryWriter.Size: SizeUInt;
begin
  Result := FSize;
end;

constructor TFixedChunkRuntime.Create(const AChunkSize: SizeUInt);
begin
  inherited Create;
  FChunkSize := AChunkSize;
end;

function TFixedChunkRuntime.NativeSocketHandle: PtrUInt;
begin
  Result := 0;
end;

procedure TFixedChunkRuntime.SetBlocking(const ABlocking: Boolean);
begin
end;

function TFixedChunkRuntime.TryRead(var ABuf; const ACount: SizeUInt;
  out ARead: SizeUInt): TTcpStreamIOResult;
begin
  ARead := 0;
  Result := tsiorClosed;
end;

function TFixedChunkRuntime.TryWrite(const ABuf; const ACount: SizeUInt;
  out AWritten: SizeUInt): TTcpStreamIOResult;
begin
  AWritten := ACount;
  if (FChunkSize > 0) and (AWritten > FChunkSize) then
    AWritten := FChunkSize;
  Inc(FBytesAccepted, AWritten);
  Result := tsiorOk;
end;

procedure TFixedChunkRuntime.Reset;
begin
  FBytesAccepted := 0;
end;

function TFixedChunkRuntime.BytesAccepted: SizeUInt;
begin
  Result := FBytesAccepted;
end;

procedure InitPayload;
var
  I: SizeInt;
begin
  for I := 0 to High(GPayload) do
    GPayload[I] := Byte(I and $FF);
  if GPayload[0] = 255 then
    Inc(GBytesDrained);
end;

procedure BenchBufferWriteDrain1KB(aIters: Int64);
var
  LIt: Int64;
  LBuffer: IH1OutboundBuffer;
  LSink: TFixedMemoryWriter;
  LSinkWriter: IWriter;
begin
  LSink := TFixedMemoryWriter.Create;
  LSinkWriter := LSink as IWriter;
  try
    for LIt := 1 to aIters do
    begin
      LSink.Reset;
      LBuffer := NewH1OutboundBuffer;
      LBuffer.Write(GPayload[0], SizeUInt(Length(GPayload)));
      LBuffer.DrainAllTo(LSinkWriter);
      Inc(GBytesDrained, LSink.Size);
    end;
  finally
    LSinkWriter := nil;
  end;
end;

procedure BenchBufferTryDrainRuntime1KBChunk128(aIters: Int64);
var
  LIt: Int64;
  LBuffer: IH1OutboundBuffer;
  LRuntime: TFixedChunkRuntime;
  LRuntimeIntf: ITcpStreamRuntime;
  LWritten: SizeUInt;
begin
  LRuntime := TFixedChunkRuntime.Create(128);
  LRuntimeIntf := LRuntime as ITcpStreamRuntime;
  try
    for LIt := 1 to aIters do
    begin
      LRuntime.Reset;
      LBuffer := NewH1OutboundBuffer;
      LBuffer.Write(GPayload[0], SizeUInt(Length(GPayload)));
      while not LBuffer.IsEmpty do
        LBuffer.TryDrainTo(LRuntimeIntf, LWritten);
      Inc(GBytesDrained, LRuntime.BytesAccepted);
    end;
  finally
    LRuntimeIntf := nil;
  end;
end;

begin
  InitPayload;
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.http.h1outbound benchmark ===');
  WriteLn('operation=http.h1outbound.drain');
  WriteLn;
  B.Run('buffer write+drain 1KB', @BenchBufferWriteDrain1KB);
  B.Run('buffer trydrain runtime 1KB chunk128',
    @BenchBufferTryDrainRuntime1KBChunk128);
  WriteLn;
  B.Summary;
  B.Free;
end.
