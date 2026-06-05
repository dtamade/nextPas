program bench_h1outbound;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.io.intf,
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

begin
  InitPayload;
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.http.h1outbound benchmark ===');
  WriteLn('operation=http.h1outbound.drain');
  WriteLn;
  B.Run('buffer write+drain 1KB', @BenchBufferWriteDrain1KB);
  WriteLn;
  B.Summary;
  B.Free;
end.
