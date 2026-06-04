program bench_h1parser;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.http.impl.h1.parser,
  nextpas.core.http.impl.h1.fast,
  nextpas.core.http.impl.h1.llhttp;

var
  B: TBenchRunner;
  GSink: SizeUInt;
  GCallbackSink: SizeUInt;

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

{ === Raw translated llhttp benchmarks === }

procedure BenchRawLlhttpRequest(const ARequest: AnsiString; aIters: Int64);
var
  LIt: Int64;
  LParser: TLlhttpInternalT;
  LSettings: TLlhttpSettingsT;
  LErr: TLlhttpErrnoT;
begin
  llhttp_settings_init(@LSettings);
  llhttp_init(@LParser, HTTP_REQUEST, @LSettings);
  for LIt := 1 to aIters do
  begin
    llhttp_reset(@LParser);
    LErr := llhttp_execute(@LParser, PAnsiChar(ARequest), Length(ARequest));
    if LErr <> HPE_OK then
      Inc(GSink);
  end;
  GSink := GSink + LParser.http_major + LParser.http_minor + LParser.method;
end;

function NoopDataCb(p0: PTLlhttpInternalT; p1: PAnsiChar; p2: SizeUInt): LongInt; cdecl;
begin
  GCallbackSink := GCallbackSink + p2;
  Result := 0;
end;

function NoopCb(p0: PTLlhttpInternalT): LongInt; cdecl;
begin
  Inc(GCallbackSink);
  Result := 0;
end;

function PauseOnMessageCompleteCb(p0: PTLlhttpInternalT): LongInt; cdecl;
begin
  Inc(GCallbackSink);
  Result := HPE_PAUSED;
end;

procedure InstallNoopCallbacks(var ASettings: TLlhttpSettingsT);
begin
  ASettings.on_url := @NoopDataCb;
  ASettings.on_header_field := @NoopDataCb;
  ASettings.on_header_value := @NoopDataCb;
  ASettings.on_body := @NoopDataCb;
  ASettings.on_headers_complete := @NoopCb;
  ASettings.on_message_complete := @NoopCb;
end;

procedure BenchPausedPipelineWithSettings(var ASettings: TLlhttpSettingsT;
  aIters: Int64);
var
  LIt: Int64;
  LParser: TLlhttpInternalT;
  LErr: TLlhttpErrnoT;
  LPos: SizeUInt;
  LConsumed: SizeUInt;
  LErrorPos: PAnsiChar;
begin
  llhttp_init(@LParser, HTTP_REQUEST, @ASettings);
  for LIt := 1 to aIters do
  begin
    LPos := 0;
    while LPos < SizeUInt(Length(GPipeline)) do
    begin
      llhttp_reset(@LParser);
      LErr := llhttp_execute(@LParser, PAnsiChar(GPipeline) + LPos,
        SizeUInt(Length(GPipeline)) - LPos);
      if LErr <> HPE_PAUSED then
      begin
        Inc(GSink);
        Break;
      end;
      LErrorPos := llhttp_get_error_pos(@LParser);
      if (LErrorPos = nil) or
         (PtrUInt(LErrorPos) < PtrUInt(PAnsiChar(GPipeline) + LPos)) then
        Break;
      LConsumed := SizeUInt(PtrUInt(LErrorPos) -
        PtrUInt(PAnsiChar(GPipeline) + LPos));
      if LConsumed = 0 then
        Break;
      Inc(LPos, LConsumed);
    end;
  end;
  GSink := GSink + GCallbackSink + LPos;
end;

procedure BenchNoopLlhttpRequest(const ARequest: AnsiString; aIters: Int64);
var
  LIt: Int64;
  LParser: TLlhttpInternalT;
  LSettings: TLlhttpSettingsT;
  LErr: TLlhttpErrnoT;
begin
  GCallbackSink := 0;
  llhttp_settings_init(@LSettings);
  InstallNoopCallbacks(LSettings);
  llhttp_init(@LParser, HTTP_REQUEST, @LSettings);
  for LIt := 1 to aIters do
  begin
    llhttp_reset(@LParser);
    LErr := llhttp_execute(@LParser, PAnsiChar(ARequest), Length(ARequest));
    if LErr <> HPE_OK then
      Inc(GSink);
  end;
  GSink := GSink + GCallbackSink + LParser.http_major + LParser.http_minor +
    LParser.method;
end;

procedure BenchRawLlhttpSimpleGET(aIters: Int64);
begin
  BenchRawLlhttpRequest(REQ_SIMPLE, aIters);
end;

procedure BenchRawLlhttp10Headers(aIters: Int64);
begin
  BenchRawLlhttpRequest(REQ_10HEADERS, aIters);
end;

procedure BenchRawLlhttpPost1K(aIters: Int64);
begin
  BenchRawLlhttpRequest(GReqPost1K, aIters);
end;

procedure BenchRawLlhttpPipelinePauseOnly(aIters: Int64);
var
  LSettings: TLlhttpSettingsT;
begin
  GCallbackSink := 0;
  llhttp_settings_init(@LSettings);
  LSettings.on_message_complete := @PauseOnMessageCompleteCb;
  BenchPausedPipelineWithSettings(LSettings, aIters);
end;

procedure BenchNoopLlhttpSimpleGET(aIters: Int64);
begin
  BenchNoopLlhttpRequest(REQ_SIMPLE, aIters);
end;

procedure BenchNoopLlhttp10Headers(aIters: Int64);
begin
  BenchNoopLlhttpRequest(REQ_10HEADERS, aIters);
end;

procedure BenchNoopLlhttpPost1K(aIters: Int64);
begin
  BenchNoopLlhttpRequest(GReqPost1K, aIters);
end;

procedure BenchNoopLlhttpPipeline10(aIters: Int64);
var
  LSettings: TLlhttpSettingsT;
begin
  GCallbackSink := 0;
  llhttp_settings_init(@LSettings);
  InstallNoopCallbacks(LSettings);
  LSettings.on_message_complete := @PauseOnMessageCompleteCb;
  BenchPausedPipelineWithSettings(LSettings, aIters);
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
  WriteLn('--- raw translated llhttp (no callbacks) ---');
  B.Run('raw llhttp: simple GET (~60B)', @BenchRawLlhttpSimpleGET);
  B.Run('raw llhttp: 10 headers (~400B)', @BenchRawLlhttp10Headers);
  B.Run('raw llhttp: POST 1KB body', @BenchRawLlhttpPost1K);
  B.Run('raw llhttp: pipeline pause-only (10 reqs)', @BenchRawLlhttpPipelinePauseOnly);
  WriteLn;
  WriteLn('--- translated llhttp with no-op callbacks ---');
  B.Run('noop cb: simple GET (~60B)', @BenchNoopLlhttpSimpleGET);
  B.Run('noop cb: 10 headers (~400B)', @BenchNoopLlhttp10Headers);
  B.Run('noop cb: POST 1KB body', @BenchNoopLlhttpPost1K);
  B.Run('noop cb: pipeline (10 reqs)', @BenchNoopLlhttpPipeline10);
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
