program bench_h1parser;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.bench,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.impl.h1.parser,
  nextpas.core.http.impl.h1.fast,
  nextpas.core.http.impl.h1.llhttp;

var
  B: TBenchRunner;
  GSink: SizeUInt;
  GCallbackSink: SizeUInt;

const
  REQ_SIMPLE: AnsiString = 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;

  REQ_ADAPTER_NO_URL: AnsiString =
    'GET / HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Connection: keep-alive'#13#10 +
    'Content-Length: 0'#13#10 +
    #13#10;

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
  LRequestPtr: PAnsiChar;
  LRequestLen: SizeUInt;
begin
  LRequestPtr := PAnsiChar(ARequest);
  LRequestLen := SizeUInt(Length(ARequest));
  llhttp_settings_init(@LSettings);
  llhttp_init(@LParser, HTTP_REQUEST, @LSettings);
  for LIt := 1 to aIters do
  begin
    llhttp_reset(@LParser);
    LErr := llhttp_execute(@LParser, LRequestPtr, LRequestLen);
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
  LRequestPtr: PAnsiChar;
  LRequestLen: SizeUInt;
begin
  LRequestPtr := PAnsiChar(ARequest);
  LRequestLen := SizeUInt(Length(ARequest));
  GCallbackSink := 0;
  llhttp_settings_init(@LSettings);
  InstallNoopCallbacks(LSettings);
  llhttp_init(@LParser, HTTP_REQUEST, @LSettings);
  for LIt := 1 to aIters do
  begin
    llhttp_reset(@LParser);
    LErr := llhttp_execute(@LParser, LRequestPtr, LRequestLen);
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

{ === Adapter materialization cost breakdown === }

procedure AppendBenchSpan(var AText: string; const AData: PAnsiChar;
  const ALen: SizeUInt);
var
  LOldLen: SizeInt;
begin
  if ALen = 0 then
    Exit;
  LOldLen := Length(AText);
  if LOldLen = 0 then
  begin
    SetString(AText, AData, ALen);
    Exit;
  end;
  SetLength(AText, LOldLen + SizeInt(ALen));
  Move(AData^, AText[LOldLen + 1], ALen);
end;

procedure AppendBenchLiteral(var AText: string; const ALiteral: AnsiString);
begin
  AppendBenchSpan(AText, PAnsiChar(ALiteral), Length(ALiteral));
end;

procedure AppendBenchHeaderPair(var AField, AValue: string;
  const AName, AHeaderValue: AnsiString);
begin
  AppendBenchLiteral(AField, AName);
  AppendBenchLiteral(AValue, AHeaderValue);
  GSink := GSink + SizeUInt(Length(AField)) + SizeUInt(Length(AValue));
  AField := '';
  AValue := '';
end;

procedure BenchAdapterSpanAppend10Headers(aIters: Int64);
var
  LIt: Int64;
  LUrl: string;
  LField: string;
  LValue: string;
begin
  for LIt := 1 to aIters do
  begin
    LUrl := '';
    LField := '';
    LValue := '';
    AppendBenchLiteral(LUrl, '/api/v1/users');
    AppendBenchHeaderPair(LField, LValue, 'Host', 'example.com');
    AppendBenchHeaderPair(LField, LValue, 'User-Agent', 'nextpas/1.0');
    AppendBenchHeaderPair(LField, LValue, 'Accept', 'application/json');
    AppendBenchHeaderPair(LField, LValue, 'Accept-Encoding', 'gzip, deflate');
    AppendBenchHeaderPair(LField, LValue, 'Accept-Language', 'en-US');
    AppendBenchHeaderPair(LField, LValue, 'Connection', 'keep-alive');
    AppendBenchHeaderPair(LField, LValue, 'Cache-Control', 'no-cache');
    AppendBenchHeaderPair(LField, LValue, 'X-Request-Id', 'abc123');
    AppendBenchHeaderPair(LField, LValue, 'X-Forwarded-For', '10.0.0.1');
    AppendBenchHeaderPair(LField, LValue, 'Authorization', 'Bearer token123');
  end;
  GSink := GSink + SizeUInt(Length(LUrl));
end;

procedure BenchAdapterHeaderAdd10Headers(aIters: Int64);
var
  LIt: Int64;
  LHeaders: THttpHeaders;
begin
  LHeaders := THttpHeaders.Create;
  for LIt := 1 to aIters do
  begin
    LHeaders.Clear;
    LHeaders.AddParsed('Host', 'example.com');
    LHeaders.AddParsed('User-Agent', 'nextpas/1.0');
    LHeaders.AddParsed('Accept', 'application/json');
    LHeaders.AddParsed('Accept-Encoding', 'gzip, deflate');
    LHeaders.AddParsed('Accept-Language', 'en-US');
    LHeaders.AddParsed('Connection', 'keep-alive');
    LHeaders.AddParsed('Cache-Control', 'no-cache');
    LHeaders.AddParsed('X-Request-Id', 'abc123');
    LHeaders.AddParsed('X-Forwarded-For', '10.0.0.1');
    LHeaders.AddParsed('Authorization', 'Bearer token123');
  end;
  GSink := GSink + SizeUInt(LHeaders.Count);
  LHeaders.Free;
end;

procedure AddBenchParsedHeaderSpan(const AHeaders: THttpHeaders;
  const AName, AHeaderValue: AnsiString);
begin
  AHeaders.AddParsedSpans(PAnsiChar(AName), Length(AName),
    PAnsiChar(AHeaderValue), Length(AHeaderValue));
end;

procedure BenchAdapterHeaderSpanAdd10Headers(aIters: Int64);
var
  LIt: Int64;
  LHeaders: THttpHeaders;
begin
  LHeaders := THttpHeaders.Create;
  for LIt := 1 to aIters do
  begin
    LHeaders.Clear;
    AddBenchParsedHeaderSpan(LHeaders, 'Host', 'example.com');
    AddBenchParsedHeaderSpan(LHeaders, 'User-Agent', 'nextpas/1.0');
    AddBenchParsedHeaderSpan(LHeaders, 'Accept', 'application/json');
    AddBenchParsedHeaderSpan(LHeaders, 'Accept-Encoding', 'gzip, deflate');
    AddBenchParsedHeaderSpan(LHeaders, 'Accept-Language', 'en-US');
    AddBenchParsedHeaderSpan(LHeaders, 'Connection', 'keep-alive');
    AddBenchParsedHeaderSpan(LHeaders, 'Cache-Control', 'no-cache');
    AddBenchParsedHeaderSpan(LHeaders, 'X-Request-Id', 'abc123');
    AddBenchParsedHeaderSpan(LHeaders, 'X-Forwarded-For', '10.0.0.1');
    AddBenchParsedHeaderSpan(LHeaders, 'Authorization', 'Bearer token123');
  end;
  GSink := GSink + SizeUInt(LHeaders.Count);
  LHeaders.Free;
end;

procedure EnsureBenchBodyCapacity(var ABody: TBytes; const ARequired: SizeUInt);
var
  LNewCapacity: SizeUInt;
begin
  if SizeUInt(Length(ABody)) >= ARequired then
    Exit;

  LNewCapacity := SizeUInt(Length(ABody));
  if LNewCapacity < 256 then
    LNewCapacity := 256;
  while LNewCapacity < ARequired do
    LNewCapacity := LNewCapacity * 2;
  SetLength(ABody, SizeInt(LNewCapacity));
end;

procedure BenchAdapterBodyCopy1K(aIters: Int64);
var
  LIt: Int64;
  LBody: TBytes;
  LBodySize: SizeUInt;
  LCopySize: SizeUInt;
begin
  LCopySize := SizeUInt(Length(GBody1K));
  for LIt := 1 to aIters do
  begin
    LBodySize := 0;
    EnsureBenchBodyCapacity(LBody, LCopySize);
    Move(GBody1K[1], LBody[LBodySize], LCopySize);
    LBodySize := LCopySize;
  end;
  GSink := GSink + LBodySize + LBody[0];
end;

procedure BenchAdapterUrlParseGenericOriginForm(aIters: Int64);
var
  LIt: Int64;
  LUrl: TUrl;
  LScore: SizeUInt;
begin
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LUrl := TUrl.Parse('/api/v1/users?page=2&filter=active#top');
    LScore := LScore + SizeUInt(Length(LUrl.Path)) +
      SizeUInt(Length(LUrl.RawQuery)) + SizeUInt(Length(LUrl.Fragment));
  end;
  GSink := GSink + LScore;
end;

procedure BenchAdapterUrlParseRequestTargetOriginForm(aIters: Int64);
var
  LIt: Int64;
  LUrl: TUrl;
  LScore: SizeUInt;
begin
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LUrl := TUrl.ParseRequestTarget('/api/v1/users?page=2&filter=active#top');
    LScore := LScore + SizeUInt(Length(LUrl.Path)) +
      SizeUInt(Length(LUrl.RawQuery)) + SizeUInt(Length(LUrl.Fragment));
  end;
  GSink := GSink + LScore;
end;

procedure BenchAdapterRequestCreateEagerUrlParse(aIters: Int64);
var
  LIt: Int64;
  LHeaders: IHttpHeaders;
  LReq: IHttpRequest;
  LUrl: TUrl;
  LScore: SizeUInt;
begin
  LHeaders := NewHttpHeaders;
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LUrl := TUrl.ParseRequestTarget('/api/v1/users?page=2&filter=active#top');
    LReq := THttpRequest.Create(hmGet, LUrl, hvHttp11, LHeaders, nil, 0);
    LScore := LScore + SizeUInt(Ord(LReq.Method)) +
      SizeUInt(LReq.ContentLength);
  end;
  GSink := GSink + LScore;
end;

procedure BenchAdapterRequestCreateLazyTarget(aIters: Int64);
var
  LIt: Int64;
  LHeaders: IHttpHeaders;
  LReq: IHttpRequest;
  LScore: SizeUInt;
begin
  LHeaders := NewHttpHeaders;
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LReq := THttpRequest.CreateFromRequestTarget(hmGet,
      '/api/v1/users?page=2&filter=active#top', hvHttp11, LHeaders, nil, 0);
    LScore := LScore + SizeUInt(Ord(LReq.Method)) +
      SizeUInt(LReq.ContentLength);
  end;
  GSink := GSink + LScore;
end;

procedure BenchAdapterRequestLazyUrlPathAccess(aIters: Int64);
var
  LIt: Int64;
  LHeaders: IHttpHeaders;
  LReq: IHttpRequest;
  LScore: SizeUInt;
begin
  LHeaders := NewHttpHeaders;
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LReq := THttpRequest.CreateFromRequestTarget(hmGet,
      '/api/v1/users?page=2&filter=active#top', hvHttp11, LHeaders, nil, 0);
    LScore := LScore + SizeUInt(Length(LReq.Url.Path));
  end;
  GSink := GSink + LScore;
end;

procedure BenchAdapterRequestDirectPathAccess(aIters: Int64);
var
  LIt: Int64;
  LHeaders: IHttpHeaders;
  LReq: IHttpRequest;
  LScore: SizeUInt;
begin
  LHeaders := NewHttpHeaders;
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LReq := THttpRequest.CreateFromRequestTarget(hmGet,
      '/api/v1/users?page=2&filter=active#top', hvHttp11, LHeaders, nil, 0);
    LScore := LScore + SizeUInt(Length(LReq.Path));
  end;
  GSink := GSink + LScore;
end;

procedure BenchAdapterRequestDirectRawQueryAccess(aIters: Int64);
var
  LIt: Int64;
  LHeaders: IHttpHeaders;
  LReq: IHttpRequest;
  LScore: SizeUInt;
begin
  LHeaders := NewHttpHeaders;
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LReq := THttpRequest.CreateFromRequestTarget(hmGet,
      '/api/v1/users?page=2&filter=active#top', hvHttp11, LHeaders, nil, 0);
    LScore := LScore + SizeUInt(Length(LReq.RawQuery));
  end;
  GSink := GSink + LScore;
end;

procedure BenchAdapterRequestDirectPathAndRawQueryAccess(aIters: Int64);
var
  LIt: Int64;
  LHeaders: IHttpHeaders;
  LReq: IHttpRequest;
  LScore: SizeUInt;
begin
  LHeaders := NewHttpHeaders;
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LReq := THttpRequest.CreateFromRequestTarget(hmGet,
      '/api/v1/users?page=2&filter=active#top', hvHttp11, LHeaders, nil, 0);
    LScore := LScore + SizeUInt(Length(LReq.Path)) +
      SizeUInt(Length(LReq.RawQuery));
  end;
  GSink := GSink + LScore;
end;

function BenchTryGetDeclaredContentLength(const AHeaders: IHttpHeaders;
  out AContentLength: Int64): Boolean;
var
  LContentLength: string;
begin
  AContentLength := 0;
  LContentLength := Trim(AHeaders.Get('content-length'));
  Result := (LContentLength <> '') and
    TryStrToInt64(LContentLength, AContentLength);
end;

function BenchRequestDeclaresBody(const AHeaders: IHttpHeaders): Boolean;
var
  LTransferEncoding: string;
  LContentLength: Int64;
begin
  LTransferEncoding := LowerCase(Trim(AHeaders.Get('transfer-encoding')));
  if LTransferEncoding <> '' then
    Exit(True);
  Result := BenchTryGetDeclaredContentLength(AHeaders, LContentLength) and
    (LContentLength > 0);
end;

function BenchRequestExpectsContinue(const AHeaders: IHttpHeaders): Boolean;
var
  LValues: TStringArray;
  LI: SizeInt;
  LExpect: string;
  LStart: SizeInt;
  LPos: SizeInt;
  LToken: string;
begin
  Result := False;
  LValues := AHeaders.GetAll('expect');
  for LI := 0 to High(LValues) do
  begin
    LExpect := Trim(LValues[LI]);
    if LExpect = '' then
      Continue;
    LStart := 1;
    while LStart <= Length(LExpect) do
    begin
      LPos := LStart;
      while (LPos <= Length(LExpect)) and (LExpect[LPos] <> ',') do
        Inc(LPos);
      LToken := LowerCase(Trim(Copy(LExpect, LStart, LPos - LStart)));
      if LToken = '100-continue' then
        Exit(True);
      LStart := LPos + 1;
    end;
  end;
end;

function BenchRequestHasUnsupportedExpectations(
  const AHeaders: IHttpHeaders): Boolean;
var
  LValues: TStringArray;
  LI: SizeInt;
  LExpect: string;
  LStart: SizeInt;
  LPos: SizeInt;
  LToken: string;
begin
  Result := False;
  LValues := AHeaders.GetAll('expect');
  for LI := 0 to High(LValues) do
  begin
    LExpect := Trim(LValues[LI]);
    if LExpect = '' then
      Continue;
    LStart := 1;
    while LStart <= Length(LExpect) do
    begin
      LPos := LStart;
      while (LPos <= Length(LExpect)) and (LExpect[LPos] <> ',') do
        Inc(LPos);
      LToken := LowerCase(Trim(Copy(LExpect, LStart, LPos - LStart)));
      if (LToken <> '') and (LToken <> '100-continue') then
        Exit(True);
      LStart := LPos + 1;
    end;
  end;
end;

procedure InitBenchMetadataHeaders(const AHeaders: IHttpHeaders);
begin
  AHeaders.SetHeader('host', 'example.com');
  AHeaders.SetHeader('connection', 'keep-alive');
  AHeaders.SetHeader('expect', '100-continue, fancy');
  AHeaders.SetHeader('content-length', '1024');
  AHeaders.SetHeader('content-type', 'application/octet-stream');
  AHeaders.SetHeader('user-agent', 'nextpas/1.0');
  AHeaders.SetHeader('accept', 'application/json');
  AHeaders.SetHeader('cache-control', 'no-cache');
  AHeaders.SetHeader('x-request-id', 'abc123');
  AHeaders.SetHeader('authorization', 'Bearer token123');
end;

procedure BenchAdapterRequestMetadataLegacyExpectCl(aIters: Int64);
var
  LIt: Int64;
  LHeaders: IHttpHeaders;
  LContentLength: Int64;
  LScore: SizeUInt;
begin
  LHeaders := NewHttpHeaders;
  InitBenchMetadataHeaders(LHeaders);
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    if LHeaders.Get('host') <> '' then
      Inc(LScore);
    if BenchRequestHasUnsupportedExpectations(LHeaders) then
      Inc(LScore);
    if BenchTryGetDeclaredContentLength(LHeaders, LContentLength) and
       (LContentLength > 512) then
      Inc(LScore);
    if BenchRequestExpectsContinue(LHeaders) and
       BenchRequestDeclaresBody(LHeaders) then
      Inc(LScore);
    if LHeaders.Get('connection') = 'keep-alive' then
      Inc(LScore);
  end;
  GSink := GSink + LScore;
end;

procedure BenchAdapterRequestMetadataCachedExpectCl(aIters: Int64);
var
  LIt: Int64;
  LMetadata: TH1RequestMetadata;
  LScore: SizeUInt;
begin
  LMetadata := Default(TH1RequestMetadata);
  LMetadata.HasHost := True;
  LMetadata.HasContentLength := True;
  LMetadata.DeclaredContentLength := 1024;
  LMetadata.RequestDeclaresBody := True;
  LMetadata.ExpectsContinue := True;
  LMetadata.HasUnsupportedExpect := True;
  LMetadata.ConnectionKeepAlive := True;
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    if LMetadata.HasHost then
      Inc(LScore);
    if LMetadata.HasUnsupportedExpect then
      Inc(LScore);
    if LMetadata.HasContentLength and
       (LMetadata.DeclaredContentLength > 512) then
      Inc(LScore);
    if LMetadata.ExpectsContinue and LMetadata.RequestDeclaresBody then
      Inc(LScore);
    if LMetadata.ConnectionKeepAlive then
      Inc(LScore);
  end;
  GSink := GSink + LScore;
end;

procedure InitBenchAdapterNoUrlHeaders(const AHeaders: IHttpHeaders);
begin
  AHeaders.SetHeader('host', 'localhost');
  AHeaders.SetHeader('connection', 'keep-alive');
  AHeaders.SetHeader('content-length', '0');
end;

procedure BenchAdapterNoUrlMetadata3Headers(aIters: Int64);
var
  LIt: Int64;
  LHeaders: IHttpHeaders;
  LContentLength: Int64;
  LScore: SizeUInt;
begin
  LHeaders := NewHttpHeaders;
  InitBenchAdapterNoUrlHeaders(LHeaders);
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    if LHeaders.Get('host') <> '' then
      Inc(LScore);
    if LHeaders.Get('connection') = 'keep-alive' then
      Inc(LScore);
    if BenchTryGetDeclaredContentLength(LHeaders, LContentLength) and
       (LContentLength = 0) then
      Inc(LScore);
    if not BenchRequestDeclaresBody(LHeaders) then
      Inc(LScore);
  end;
  GSink := GSink + LScore;
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

procedure BenchFastParseAdapterNoUrl(aIters: Int64);
var
  LIt: Int64;
  LResult: TFastParseResult;
  LScore: SizeUInt;
begin
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LResult := FastParseRequest(PAnsiChar(REQ_ADAPTER_NO_URL),
      Length(REQ_ADAPTER_NO_URL));
    if LResult.Success then
      LScore := LScore + LResult.Consumed;
    if LResult.HasConnection then
      Inc(LScore);
  end;
  GSink := GSink + LScore;
end;

procedure BenchFastHeadersGetHostOnly(aIters: Int64);
var
  LIt: Int64;
  LResult: TFastParseResult;
  LScore: SizeUInt;
begin
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LResult := FastParseRequest(PAnsiChar(REQ_10HEADERS), Length(REQ_10HEADERS));
    if LResult.Success then
      LScore := LScore + SizeUInt(Length(LResult.Headers.Get('Host')));
  end;
  GSink := GSink + LScore;
end;

procedure BenchFastHeadersCountAll(aIters: Int64);
var
  LIt: Int64;
  LResult: TFastParseResult;
  LScore: SizeUInt;
begin
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LResult := FastParseRequest(PAnsiChar(REQ_10HEADERS), Length(REQ_10HEADERS));
    if LResult.Success then
      LScore := LScore + SizeUInt(LResult.Headers.Count);
  end;
  GSink := GSink + LScore;
end;

procedure BenchFastHeadersHasAccept(aIters: Int64);
var
  LIt: Int64;
  LResult: TFastParseResult;
  LScore: SizeUInt;
begin
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LResult := FastParseRequest(PAnsiChar(REQ_10HEADERS), Length(REQ_10HEADERS));
    if LResult.Success and LResult.Headers.Has('Accept') then
      Inc(LScore);
  end;
  GSink := GSink + LScore;
end;

procedure BenchFastHeadersGetAllAccept(aIters: Int64);
var
  LIt: Int64;
  LI: SizeInt;
  LResult: TFastParseResult;
  LValues: TStringArray;
  LScore: SizeUInt;
begin
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LResult := FastParseRequest(PAnsiChar(REQ_10HEADERS), Length(REQ_10HEADERS));
    if LResult.Success then
    begin
      LValues := LResult.Headers.GetAll('Accept');
      for LI := 0 to High(LValues) do
        LScore := LScore + SizeUInt(Length(LValues[LI]));
    end;
  end;
  GSink := GSink + LScore;
end;

procedure BenchFastHeadersForEachAll(aIters: Int64);
var
  LIt: Int64;
  LResult: TFastParseResult;
  LScore: SizeUInt;
begin
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LResult := FastParseRequest(PAnsiChar(REQ_10HEADERS), Length(REQ_10HEADERS));
    if LResult.Success then
      LResult.Headers.ForEach(
        procedure(const AName, AValue: string)
        begin
          LScore := LScore + SizeUInt(Length(AName) + Length(AValue));
        end);
  end;
  GSink := GSink + LScore;
end;

procedure BenchParseAdapterNoUrl(aIters: Int64);
var
  LIt: Int64;
  LP: IH1Parser;
  LScore: SizeUInt;
begin
  LP := NewH1RequestParser;
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LP.Reset;
    LScore := LScore + LP.Execute(PAnsiChar(REQ_ADAPTER_NO_URL),
      Length(REQ_ADAPTER_NO_URL));
  end;
  GSink := GSink + LScore;
end;

procedure BenchAdapterNoUrlLegacyDoubleParseExplicitKeepAlive(aIters: Int64);
var
  LIt: Int64;
  LP: IH1Parser;
  LFast: TFastParseResult;
  LScore: SizeUInt;
begin
  LP := NewH1RequestParser;
  LScore := 0;
  for LIt := 1 to aIters do
  begin
    LFast := FastParseRequest(PAnsiChar(REQ_ADAPTER_NO_URL),
      Length(REQ_ADAPTER_NO_URL));
    if LFast.Success and LFast.HasConnection then
    begin
      Inc(LScore);
      LP.Reset;
      LScore := LScore + LP.Execute(PAnsiChar(REQ_ADAPTER_NO_URL),
        Length(REQ_ADAPTER_NO_URL));
    end
    else if LFast.Success then
      LScore := LScore + LFast.Consumed;
  end;
  GSink := GSink + LScore;
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
  WriteLn('operation=http.h1parser');
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
  WriteLn('--- adapter materialization costs ---');
  B.Run('adapter cost: span append 10 headers', @BenchAdapterSpanAppend10Headers);
  B.Run('adapter cost: header add 10 headers', @BenchAdapterHeaderAdd10Headers);
  B.Run('adapter cost: header span add 10 headers', @BenchAdapterHeaderSpanAdd10Headers);
  B.Run('adapter cost: body copy 1KB', @BenchAdapterBodyCopy1K);
  B.Run('adapter cost: url parse generic origin-form',
    @BenchAdapterUrlParseGenericOriginForm);
  B.Run('adapter cost: url parse request-target origin-form',
    @BenchAdapterUrlParseRequestTargetOriginForm);
  B.Run('adapter cost: request create eager url parse',
    @BenchAdapterRequestCreateEagerUrlParse);
  B.Run('adapter cost: request create lazy target',
    @BenchAdapterRequestCreateLazyTarget);
  B.Run('adapter cost: request lazy Url.Path access',
    @BenchAdapterRequestLazyUrlPathAccess);
  B.Run('adapter cost: request direct Path access',
    @BenchAdapterRequestDirectPathAccess);
  B.Run('adapter cost: request direct RawQuery access',
    @BenchAdapterRequestDirectRawQueryAccess);
  B.Run('adapter cost: request direct Path+RawQuery access',
    @BenchAdapterRequestDirectPathAndRawQueryAccess);
  B.Run('adapter cost: request metadata legacy expect+cl',
    @BenchAdapterRequestMetadataLegacyExpectCl);
  B.Run('adapter cost: request metadata cached expect+cl',
    @BenchAdapterRequestMetadataCachedExpectCl);
  B.Run('adapter cost: fast headers get host only',
    @BenchFastHeadersGetHostOnly);
  B.Run('adapter cost: fast headers count all',
    @BenchFastHeadersCountAll);
  B.Run('adapter cost: fast headers has accept',
    @BenchFastHeadersHasAccept);
  B.Run('adapter cost: fast headers get all accept',
    @BenchFastHeadersGetAllAccept);
  B.Run('adapter cost: fast headers foreach all',
    @BenchFastHeadersForEachAll);
  B.Run('adapter no-url: metadata 3 headers',
    @BenchAdapterNoUrlMetadata3Headers);
  B.Run('adapter no-url: legacy double parse explicit keep-alive',
    @BenchAdapterNoUrlLegacyDoubleParseExplicitKeepAlive);
  B.Run('adapter no-url: llhttp direct only',
    @BenchParseAdapterNoUrl);
  B.Run('adapter no-url: fast parse only',
    @BenchFastParseAdapterNoUrl);
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
