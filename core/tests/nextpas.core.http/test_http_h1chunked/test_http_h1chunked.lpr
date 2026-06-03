program test_http_h1chunked;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.http.base,
  nextpas.core.http.impl.h1.chunked,
  nextpas.core.io.intf;

type
  TBytesWriter = class(TInterfacedObject, IWriter)
  private
    FBuf: string;
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function GetOutput: string;
  end;

  TShortWriter = class(TInterfacedObject, IWriter)
  private
    FBuf: string;
    FMaxPerCall: SizeUInt;
  public
    constructor Create(const AMaxPerCall: SizeUInt);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function GetOutput: string;
  end;

  TZeroWriter = class(TInterfacedObject, IWriter)
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

function TBytesWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LOld: SizeUInt;
begin
  if ACount = 0 then
    Exit(0);
  LOld := SizeUInt(Length(FBuf));
  SetLength(FBuf, LOld + ACount);
  Move(ABuf, FBuf[LOld + 1], ACount);
  Result := ACount;
end;

function TBytesWriter.GetOutput: string;
begin
  Result := FBuf;
end;

constructor TShortWriter.Create(const AMaxPerCall: SizeUInt);
begin
  inherited Create;
  FMaxPerCall := AMaxPerCall;
end;

function TShortWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LOld: SizeUInt;
begin
  if (ACount = 0) or (FMaxPerCall = 0) then
    Exit(0);
  Result := ACount;
  if Result > FMaxPerCall then
    Result := FMaxPerCall;
  LOld := SizeUInt(Length(FBuf));
  SetLength(FBuf, LOld + Result);
  Move(ABuf, FBuf[LOld + 1], Result);
end;

function TShortWriter.GetOutput: string;
begin
  Result := FBuf;
end;

function TZeroWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;
end;

var
  T: TTestRunner;

procedure TestSingleWriteFramesOneChunk;
var
  LInner: TBytesWriter;
  LChunked: TChunkedWriter;
  LBody: string;
begin
  LInner := TBytesWriter.Create;
  LChunked := TChunkedWriter.Create(LInner as IWriter);
  LBody := 'hello';
  CheckEqual(Int64(5), Int64(LChunked.Write(LBody[1], SizeUInt(Length(LBody)))), 'write returns body bytes');
  CheckEqual('5'#13#10'hello'#13#10, LInner.GetOutput, 'single chunk framing');
  LChunked.Free;
end;

procedure TestMultipleWritesEmitSeparateChunks;
var
  LInner: TBytesWriter;
  LChunked: TChunkedWriter;
  LPart1: string;
  LPart2: string;
begin
  LInner := TBytesWriter.Create;
  LChunked := TChunkedWriter.Create(LInner as IWriter);
  LPart1 := 'ab';
  LPart2 := 'cde';
  LChunked.Write(LPart1[1], SizeUInt(Length(LPart1)));
  LChunked.Write(LPart2[1], SizeUInt(Length(LPart2)));
  CheckEqual('2'#13#10'ab'#13#10'3'#13#10'cde'#13#10, LInner.GetOutput, 'separate chunk framing');
  LChunked.Free;
end;

procedure TestZeroLengthWriteEmitsNothing;
var
  LInner: TBytesWriter;
  LChunked: TChunkedWriter;
  LDummy: Byte;
begin
  LInner := TBytesWriter.Create;
  LChunked := TChunkedWriter.Create(LInner as IWriter);
  LDummy := 0;
  CheckEqual(Int64(0), Int64(LChunked.Write(LDummy, 0)), 'zero-length write returns zero');
  CheckEqual('', LInner.GetOutput, 'zero-length write emits nothing');
  LChunked.Free;
end;

procedure TestFlushWritesTerminalChunkOnce;
var
  LInner: TBytesWriter;
  LChunked: TChunkedWriter;
begin
  LInner := TBytesWriter.Create;
  LChunked := TChunkedWriter.Create(LInner as IWriter);
  LChunked.Flush;
  LChunked.Flush;
  CheckEqual('0'#13#10#13#10, LInner.GetOutput, 'terminal chunk emitted once');
  LChunked.Free;
end;

procedure TestSixteenByteChunkUsesHexLength;
var
  LInner: TBytesWriter;
  LChunked: TChunkedWriter;
  LBody: string;
begin
  LInner := TBytesWriter.Create;
  LChunked := TChunkedWriter.Create(LInner as IWriter);
  LBody := '0123456789ABCDEF';
  LChunked.Write(LBody[1], SizeUInt(Length(LBody)));
  CheckEqual('10'#13#10'0123456789ABCDEF'#13#10, LInner.GetOutput, 'hex chunk length');
  LChunked.Free;
end;

procedure TestWriteAfterFlushRaises;
var
  LInner: TBytesWriter;
  LChunked: TChunkedWriter;
  LBody: string;
  LRaised: Boolean;
begin
  LInner := TBytesWriter.Create;
  LChunked := TChunkedWriter.Create(LInner as IWriter);
  LChunked.Flush;
  LBody := 'x';
  LRaised := False;
  try
    LChunked.Write(LBody[1], SizeUInt(Length(LBody)));
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'write after terminal chunk raises EHttpError');
  LChunked.Free;
end;

procedure TestShortWriterStillFramesCompleteChunk;
var
  LInner: TShortWriter;
  LChunked: TChunkedWriter;
  LBody: string;
begin
  LInner := TShortWriter.Create(1);
  LChunked := TChunkedWriter.Create(LInner as IWriter);
  LBody := 'hello';
  CheckEqual(Int64(5), Int64(LChunked.Write(LBody[1], SizeUInt(Length(LBody)))),
    'short writer still reports full body bytes');
  CheckEqual('5'#13#10'hello'#13#10, LInner.GetOutput,
    'short writer still receives complete chunk framing');
  LChunked.Free;
end;

procedure TestShortWriterFlushStillWritesTerminalChunk;
var
  LInner: TShortWriter;
  LChunked: TChunkedWriter;
begin
  LInner := TShortWriter.Create(1);
  LChunked := TChunkedWriter.Create(LInner as IWriter);
  LChunked.Flush;
  CheckEqual('0'#13#10#13#10, LInner.GetOutput,
    'short writer still receives full terminal chunk');
  LChunked.Free;
end;

procedure TestZeroProgressWriterRaises;
var
  LInner: TZeroWriter;
  LChunked: TChunkedWriter;
  LBody: string;
  LRaised: Boolean;
begin
  LInner := TZeroWriter.Create;
  LChunked := TChunkedWriter.Create(LInner as IWriter);
  LBody := 'hello';
  LRaised := False;
  try
    LChunked.Write(LBody[1], SizeUInt(Length(LBody)));
  except
    on E: EIOError do
      LRaised := True;
  end;
  Check(LRaised, 'zero-progress writer raises EIOError');
  LChunked.Free;
end;

begin
  T := TTestRunner.Create('nextpas.core.http.impl.h1.chunked');
  T.Run('Single Write frames one chunk', @TestSingleWriteFramesOneChunk);
  T.Run('Multiple Write emits separate chunks', @TestMultipleWritesEmitSeparateChunks);
  T.Run('Zero-length Write emits nothing', @TestZeroLengthWriteEmitsNothing);
  T.Run('Flush writes terminal chunk once', @TestFlushWritesTerminalChunkOnce);
  T.Run('Sixteen-byte chunk uses hex length', @TestSixteenByteChunkUsesHexLength);
  T.Run('Write after Flush raises', @TestWriteAfterFlushRaises);
  T.Run('Short writer still frames complete chunk', @TestShortWriterStillFramesCompleteChunk);
  T.Run('Short writer Flush still writes terminal chunk', @TestShortWriterFlushStillWritesTerminalChunk);
  T.Run('Zero-progress writer raises', @TestZeroProgressWriterRaises);
  T.Summary;
end.
