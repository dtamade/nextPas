program bench_h1parser;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.http.impl.h1.parser,
  nextpas.core.http.impl.h1.fast;

var
  B: TBenchRunner;
  GSink: SizeUInt;

const
  REQ_SIMPLE: AnsiString = 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;

  REQ_10HEADERS: AnsiString =
    'GET /api/v1/users HTTP/1.1'#13#10 +
    'Host: example.com'#13#10 +
    'User-Agent: nextpas/1.0'#13#10 +
    'Accept: application/json'#13#10 +
    'Accept-Encoding: gzip, deflate'#13#10 +
    'Accept-Language: en-US'#13#10 +
    'Connection: keep-alive'#13#10 +
    'Cache-Control: no-cache'#13#10 +
    'X-Request-Id: abc123'#13#10 +
    'X-Forwarded-For: 10.0.0.1'#13#10 +
    'Authorization: Bearer token123'#13#10 +
    #13#10;

  REQ_POST_1K: AnsiString =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: example.com'#13#10 +
    'Content-Type: application/octet-stream'#13#10 +
    'Content-Length: 1024'#13#10 +
    #13#10;

var
  GBody1K: AnsiString;
  GReqPost1K: AnsiString;
  GPipeline: AnsiString;

procedure InitData;
var
  LI: Int32;
begin
  SetLength(GBody1K, 1024);
  FillChar(GBody1K[1], 1024, Byte('x'));
  GReqPost1K := REQ_POST_1K + GBody1K;

  GPipeline := '';
  for LI := 1 to 10 do
    GPipeline := GPipeline + string(REQ_SIMPLE);
end;

procedure BenchParseSimpleGET(aIters: Int64);
var
  LIt: Int64;
  LP: IH1Parser;
begin
  LP := NewH1RequestParser;
  for LIt := 1 to aIters do
  begin
    LP.Reset;
    GSink := LP.Execute(PAnsiChar(REQ_SIMPLE), Length(REQ_SIMPLE));
  end;
end;

procedure BenchParse10Headers(aIters: Int64);
var
  LIt: Int64;
  LP: IH1Parser;
begin
  LP := NewH1RequestParser;
  for LIt := 1 to aIters do
  begin
    LP.Reset;
    GSink := LP.Execute(PAnsiChar(REQ_10HEADERS), Length(REQ_10HEADERS));
  end;
end;

procedure BenchParsePost1K(aIters: Int64);
var
  LIt: Int64;
  LP: IH1Parser;
begin
  LP := NewH1RequestParser;
  for LIt := 1 to aIters do
  begin
    LP.Reset;
    GSink := LP.Execute(PAnsiChar(GReqPost1K), Length(GReqPost1K));
  end;
end;

procedure BenchParsePipeline10(aIters: Int64);
var
  LIt: Int64;
  LP: IH1Parser;
  LPos: SizeUInt;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  for LIt := 1 to aIters do
  begin
    LPos := 0;
    while LPos < SizeUInt(Length(GPipeline)) do
    begin
      LP.Reset;
      LConsumed := LP.Execute(PAnsiChar(GPipeline) + LPos, SizeUInt(Length(GPipeline)) - LPos);
      if LConsumed = 0 then Break;
      Inc(LPos, LConsumed);
    end;
  end;
  GSink := LPos;
end;

{ === Fast path benchmarks === }

procedure BenchFastParseSimpleGET(aIters: Int64);
var
  LIt: Int64;
  LResult: TFastParseResult;
begin
  for LIt := 1 to aIters do
    LResult := FastParseRequest(PAnsiChar(REQ_SIMPLE), Length(REQ_SIMPLE));
  if LResult.Success then GSink := LResult.Consumed;
end;

procedure BenchFastParse10Headers(aIters: Int64);
var
  LIt: Int64;
  LResult: TFastParseResult;
begin
  for LIt := 1 to aIters do
    LResult := FastParseRequest(PAnsiChar(REQ_10HEADERS), Length(REQ_10HEADERS));
  if LResult.Success then GSink := LResult.Consumed;
end;

procedure BenchFastParsePost1K(aIters: Int64);
var
  LIt: Int64;
  LResult: TFastParseResult;
begin
  for LIt := 1 to aIters do
    LResult := FastParseRequest(PAnsiChar(GReqPost1K), Length(GReqPost1K));
  if LResult.Success then GSink := LResult.Consumed;
end;

procedure BenchFastParsePipeline10(aIters: Int64);
var
  LIt: Int64;
  LResult: TFastParseResult;
  LPos: SizeUInt;
begin
  for LIt := 1 to aIters do
  begin
    LPos := 0;
    while LPos < SizeUInt(Length(GPipeline)) do
    begin
      LResult := FastParseRequest(PAnsiChar(GPipeline) + LPos, SizeUInt(Length(GPipeline)) - LPos);
      if not LResult.Success then Break;
      Inc(LPos, LResult.Consumed);
    end;
  end;
  GSink := LPos;
end;

begin
  InitData;
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.http H1 parser benchmark ===');
  WriteLn('  Simple GET: ', Length(REQ_SIMPLE), ' bytes');
  WriteLn('  10 headers: ', Length(REQ_10HEADERS), ' bytes');
  WriteLn('  POST 1KB:   ', Length(GReqPost1K), ' bytes');
  WriteLn('  Pipeline:   ', Length(GPipeline), ' bytes (10 requests)');
  WriteLn;
  WriteLn('--- llhttp ---');
  B.Run('llhttp: simple GET (~60B)', @BenchParseSimpleGET);
  B.Run('llhttp: 10 headers (~400B)', @BenchParse10Headers);
  B.Run('llhttp: POST 1KB body', @BenchParsePost1K);
  B.Run('llhttp: pipeline (10 reqs)', @BenchParsePipeline10);
  WriteLn;
  WriteLn('--- fast path (SIMD) ---');
  B.Run('fast: simple GET (~60B)', @BenchFastParseSimpleGET);
  B.Run('fast: 10 headers (~400B)', @BenchFastParse10Headers);
  B.Run('fast: POST 1KB body', @BenchFastParsePost1K);
  B.Run('fast: pipeline (10 reqs)', @BenchFastParsePipeline10);
  WriteLn;
  B.Summary;
  B.Free;
end.
