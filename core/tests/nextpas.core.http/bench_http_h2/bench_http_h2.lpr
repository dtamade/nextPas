program bench_http_h2;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h2.frame,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.http.impl.h2.types;

var
  GStart, GEnd, GFreq: Int64;

procedure BenchStart;
begin
  GFreq := 1000000; { microseconds }
  GStart := GetTickCount64;
end;

function BenchElapsedUs: Int64;
begin
  GEnd := GetTickCount64;
  Result := (GEnd - GStart) * 1000; { ms to us }
end;

function BenchElapsedNs: Int64;
begin
  Result := BenchElapsedUs * 1000;
end;

procedure BenchHPACKEncode;
const
  ITERATIONS = 50000;
var
  LEncoder: THPackEncoder;
  LI: Integer;
  LResult: AnsiString;
  LTotalNs: Int64;
  LHeaders: array[0..4] of THPackHeader;
begin
  LHeaders[0].Name := ':method'; LHeaders[0].Value := 'POST';
  LHeaders[1].Name := ':path'; LHeaders[1].Value := '/api/v1/users';
  LHeaders[2].Name := ':authority'; LHeaders[2].Value := 'example.com';
  LHeaders[3].Name := 'content-type'; LHeaders[3].Value := 'application/json';
  LHeaders[4].Name := 'content-length'; LHeaders[4].Value := '42';
  LEncoder.Init;
  BenchStart;
  for LI := 1 to ITERATIONS do
    LResult := LEncoder.Encode(LHeaders);
  LTotalNs := BenchElapsedNs;
  WriteLn('--- HPACK Encode ---');
  WriteLn('Iterations: ', ITERATIONS);
  WriteLn('Total time: ', LTotalNs div 1000, ' us');
  WriteLn('Avg: ', LTotalNs div ITERATIONS, ' ns/op');
  if LTotalNs < 1 then LTotalNs := 1;
  WriteLn('Ops/sec: ', (ITERATIONS * 1000000000) div LTotalNs);
end;

procedure BenchHPACKDecode;
const
  ITERATIONS = 50000;
var
  LEncoder: THPackEncoder;
  LDecoder: THPackDecoder;
  LBlock: AnsiString;
  LOutput: array[0..9] of THPackHeader;
  LI: Integer;
  LTotalNs: Int64;
  LHeaders: array[0..4] of THPackHeader;
begin
  LHeaders[0].Name := ':method'; LHeaders[0].Value := 'POST';
  LHeaders[1].Name := ':path'; LHeaders[1].Value := '/api/v1/users';
  LHeaders[2].Name := ':authority'; LHeaders[2].Value := 'example.com';
  LHeaders[3].Name := 'content-type'; LHeaders[3].Value := 'application/json';
  LHeaders[4].Name := 'content-length'; LHeaders[4].Value := '42';
  LEncoder.Init;
  LBlock := LEncoder.Encode(LHeaders);
  LDecoder.Init(0);
  FillChar(LOutput, SizeOf(LOutput), 0);
  BenchStart;
  for LI := 1 to ITERATIONS do
  begin
    FillChar(LOutput, SizeOf(LOutput), 0);
    LDecoder.Decode(LBlock, LOutput);
  end;
  LTotalNs := BenchElapsedNs;
  WriteLn('--- HPACK Decode ---');
  WriteLn('Iterations: ', ITERATIONS);
  WriteLn('Total time: ', LTotalNs div 1000, ' us');
  WriteLn('Avg: ', LTotalNs div ITERATIONS, ' ns/op');
  if LTotalNs < 1 then LTotalNs := 1;
  WriteLn('Ops/sec: ', (ITERATIONS * 1000000000) div LTotalNs);
end;

procedure BenchFrameEncode;
const
  ITERATIONS = 100000;
var
  LI: Integer;
  LPayload: AnsiString;
  LResult: AnsiString;
  LTotalNs: Int64;
begin
  SetLength(LPayload, 128);
  for LI := 1 to Length(LPayload) do
    LPayload[LI] := AnsiChar(LI mod 256);

  BenchStart;
  for LI := 1 to ITERATIONS do
    LResult := H2EncodeFrame(H2_FRAME_DATA, 0, 1, LPayload);
  LTotalNs := BenchElapsedNs;
  WriteLn('--- Frame Encode ---');
  WriteLn('Iterations: ', ITERATIONS);
  WriteLn('Frame size: 128+9 bytes');
  WriteLn('Avg: ', LTotalNs div ITERATIONS, ' ns/op');
  if LTotalNs < 1 then LTotalNs := 1;
  WriteLn('Ops/sec: ', (ITERATIONS * 1000000000) div LTotalNs);
end;

procedure BenchFrameDecode;
const
  ITERATIONS = 100000;
var
  LI: Integer;
  LWire: AnsiString;
  LFrame: TH2Frame;
  LConsumed: SizeUInt;
  LPayload: AnsiString;
  LTotalNs: Int64;
begin
  SetLength(LPayload, 128);
  for LI := 1 to Length(LPayload) do
    LPayload[LI] := AnsiChar(LI mod 256);
  LWire := H2EncodeFrame(H2_FRAME_DATA, 0, 1, LPayload);

  BenchStart;
  for LI := 1 to ITERATIONS do
  begin
    LFrame := Default(TH2Frame);
    LConsumed := 0;
    H2DecodeFrame(@LWire[1], Length(LWire), LFrame, LConsumed);
  end;
  LTotalNs := BenchElapsedNs;
  WriteLn('--- Frame Decode ---');
  WriteLn('Iterations: ', ITERATIONS);
  WriteLn('Frame size: 128+9 bytes');
  WriteLn('Avg: ', LTotalNs div ITERATIONS, ' ns/op');
  if LTotalNs < 1 then LTotalNs := 1;
  WriteLn('Ops/sec: ', (ITERATIONS * 1000000000) div LTotalNs);
end;

procedure BenchFlowControlOps;
const
  ITERATIONS = 100000;
var
  LFlow: TH2FlowState;
  LI: Integer;
  LTotalNs: Int64;
begin
  LFlow.Init(65535);
  BenchStart;
  for LI := 1 to ITERATIONS do
  begin
    LFlow.TryReserve(256);
    LFlow.CommitSend(256);
    LFlow.OnWindowUpdate(256);
    LFlow.OnDataReceived(256);
    LFlow.OnDataConsumed(256);
  end;
  LTotalNs := BenchElapsedNs;
  WriteLn('--- Flow Control (5 ops/iteration) ---');
  WriteLn('Iterations: ', ITERATIONS);
  WriteLn('Total flow ops: ', ITERATIONS * 5);
  WriteLn('Avg per 5-ops cycle: ', LTotalNs div ITERATIONS, ' ns');
  WriteLn('Avg per single op: ', LTotalNs div (ITERATIONS * 5), ' ns');
  WriteLn('Flow ops/sec: ', (ITERATIONS * 5 * 1000000000) div LTotalNs);
end;

var
  LExitCode: Int32;
begin
  LExitCode := 0;
  try
    WriteLn('=== nextpas.core.http H2 Benchmarks ===');
    WriteLn;
    BenchHPACKEncode;
    BenchHPACKDecode;
    BenchFrameEncode;
    BenchFrameDecode;
    BenchFlowControlOps;
    WriteLn;
    WriteLn('All benchmarks completed.');
  except
    on E: Exception do
    begin
      WriteLn('Benchmark error: ', E.Message);
      LExitCode := 1;
    end;
  end;
  Halt(LExitCode);
end.
