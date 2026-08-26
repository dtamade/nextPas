program test_provider_anthropic;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.json,
  nextpas.core.os.env,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.fold,
  nextpas.core.agent.provider.anthropic,
  nextpas.core.agent.provider.common,
  agent.testkit,
  nextpas.core.test;

{ anthropic 适配器语义（WIRE-MAPPINGS §2 全表 + Q-A1..A8；TESTING §3
  test_provider_anthropic 行）：编码快照、解码归约、流帧 FSM、端到端装配 }

function WSpec(const N, D, P: string): TToolSpec;
begin
  Result := Default(TToolSpec);
  Result.Name := N;
  Result.Description := D;
  Result.ParametersJson := P;
end;

function ScriptResp(AStatus: Integer; const ABody: string): TScriptResponse;
begin
  Result := Default(TScriptResponse);
  Result.Status := AStatus;
  Result.BodyText := ABody;
end;

function ScriptChunks(const AChunks: TStringArray): TScriptResponse;
begin
  Result := Default(TScriptResponse);
  Result.Status := 200;
  Result.Chunks := AChunks;
end;

procedure TestEncodeMinimalSnapshot;
begin
  CheckEqual(
    '{"model":"claude-sonnet-4-5","max_tokens":64,"messages":' +
    '[{"role":"user","content":[{"type":"text","text":"hi"}]}]}',
    EncodeAnthropicRequest(
      TCompletionRequest.New('claude-sonnet-4-5')
        .WithMaxTokens(64).WithUserText('hi'), False),
    'minimal snapshot');
end;

procedure TestEncodeFullMatrix;
var
  Req: TCompletionRequest;
  Hist: TMessageArray;
  MA, MT: TMessage;
  Doc: IJsonDocument;
  LMsgs: TJsonValue;
begin
  { 历史：assistant tool_use + 工具结果（Q-A4：mrTool → user 角色消息）}
  MA := Default(TMessage);
  MA.Role := mrAssistant;
  SetLength(MA.Parts, 1);
  MA.Parts[0] := Default(TPart);
  MA.Parts[0].Kind := pkToolCall;
  MA.Parts[0].ToolCallId := 'toolu_1';
  MA.Parts[0].ToolName := 'weather';
  MA.Parts[0].ArgumentsJson := '{"city":"上海"}';
  MT := Default(TMessage);
  MT.Role := mrTool;
  SetLength(MT.Parts, 1);
  MT.Parts[0] := Default(TPart);
  MT.Parts[0].Kind := pkToolResult;
  MT.Parts[0].ToolCallId := 'toolu_1';
  MT.Parts[0].ResultJson := '{"temp":21}';
  SetLength(Hist, 3);
  Hist[0] := Default(TMessage);
  Hist[0].Role := mrSystem;
  SetLength(Hist[0].Parts, 1);
  Hist[0].Parts[0] := Default(TPart);
  Hist[0].Parts[0].Kind := pkText;
  Hist[0].Parts[0].Text := 'be terse';
  Hist[1] := MA;
  Hist[2] := MT;

  Req := TCompletionRequest.New('claude-m');
  Req.MaxTokens := 512;
  Req.Temperature := 0.7;
  Req.TopP := 0.9;
  Req.StopSequences := TStringArray.Create('END');
  Req.Thinking := tsFalse;
  Req.Tools := TToolSpecArray.Create(
    WSpec('weather', 'query weather',
      '{"type":"object","properties":{"city":{"type":"string"}}}'),
    WSpec('noargs', '', ''));
  Req.Messages := Hist;

  Doc := JsonParse(EncodeAnthropicRequest(Req, False));
  Check(not Doc.HasError, 'full encode parses');
  CheckEqual(Int64(512), Doc.Root.Get('max_tokens').AsInt,
    'max_tokens always sent (vendor required)');
  Check(Doc.Root.Get('thinking').Get('type').AsStr.ToString = 'disabled',
    'tsFalse -> thinking disabled');
  CheckEqual('weather',
    Doc.Root.Get('tools').ArrayGet(0).Get('name').AsStr.ToString,
    'flat tools entries');
  Check(Doc.Root.Get('tools').ArrayGet(1)
    .ObjectHas('input_schema'), 'empty schema defaulted');
  CheckEqual('{"type":"object"}',
    JsonStringify(Doc.Root.Get('tools').ArrayGet(1).Get('input_schema')),
    'empty schema is bare object');
  Check(Doc.Root.Get('temperature').AsFloat - 0.7 < 1e-12,
    'temperature roundtrip');
  Check(Doc.Root.Get('top_p').AsFloat - 0.9 < 1e-12, 'top_p encoded');
  CheckEqual('END',
    Doc.Root.Get('stop_sequences').ArrayGet(0).AsStr.ToString,
    'stop_sequences encoded');

  LMsgs := Doc.Root.Get('messages');
  CheckEqual(UInt32(2), LMsgs.ArrayLen,
    'system hoisted; assistant+user remain');
  CheckEqual('assistant', LMsgs.ArrayGet(0).Get('role').AsStr.ToString,
    'assistant first');
  CheckEqual('weather',
    LMsgs.ArrayGet(0).Get('content').ArrayGet(0).Get('name').AsStr.ToString,
    'tool_use block name');
  CheckEqual('"上海"',
    JsonStringify(LMsgs.ArrayGet(0).Get('content').ArrayGet(0)
      .Get('input').Get('city')), 'tool_use input is real object');
  CheckEqual('user', LMsgs.ArrayGet(1).Get('role').AsStr.ToString,
    'Q-A4 tool result rides user role');
  CheckEqual('tool_result',
    LMsgs.ArrayGet(1).Get('content').ArrayGet(0).Get('type').AsStr.ToString,
    'tool_result block type');
  CheckEqual('toolu_1',
    LMsgs.ArrayGet(1).Get('content').ArrayGet(0)
      .Get('tool_use_id').AsStr.ToString, 'result id kept');
  Check(not LMsgs.ArrayGet(1).Get('content').ArrayGet(0)
    .ObjectHas('is_error'), 'is_error sentinel absent on success (D5)');

  { 失败工具结果：is_error 仅失败时上送 }
  MT.Parts[0].IsError := True;
  Hist[2] := MT;
  Req.Messages := Hist;
  Doc := JsonParse(EncodeAnthropicRequest(Req, False));
  Check(Doc.Root.Get('messages').ArrayGet(1).Get('content').ArrayGet(0)
    .Get('is_error').IsBool and
    Doc.Root.Get('messages').ArrayGet(1).Get('content').ArrayGet(0)
      .Get('is_error').AsBool, 'is_error true on failure');
end;

procedure TestEncodeSystemMerge;
var
  Req: TCompletionRequest;
  M: TMessage;
  Sys: string;
begin
  { 顶层 System 先行 + 历史 system 文本去重合并，#10#10 连接（§0 前缀稳定）}
  M := Default(TMessage);
  M.Role := mrSystem;
  SetLength(M.Parts, 1);
  M.Parts[0] := Default(TPart);
  M.Parts[0].Kind := pkText;
  M.Parts[0].Text := 'rule B';
  Req := TCompletionRequest.New('m');
  Req.MaxTokens := 32;
  Req.System := 'rule A';
  SetLength(Req.Messages, 2);
  Req.Messages[0] := M;
  Req.Messages[1] := M;                { 同文重复：只留一份 }
  Sys := JsonParse(EncodeAnthropicRequest(Req, False))
    .Root.Get('system').AsStr.ToString;
  Check(Sys = 'rule A'#10#10'rule B', 'system dedup and join');
end;

procedure TestEncodeRejects;
var
  Code: TAgentErrorCode;
  Req: TCompletionRequest;

  function TryBad(const AReq: TCompletionRequest;
    out ACode: TAgentErrorCode): Boolean;
  begin
    Result := False;
    try
      EncodeAnthropicRequest(AReq, False);
    except
      on E: EAgentError do
      begin
        ACode := E.ErrorCode;
        Result := True;
      end;
    end;
  end;

begin
  Req := TCompletionRequest.New('m');
  Check(TryBad(Req, Code) and (Code = aecConfig),
    'missing max_tokens rejected (vendor hard requirement)');
  Req := TCompletionRequest.New('m').WithMaxTokens(64);
  Req.Thinking := tsTrue;
  Check(TryBad(Req, Code) and (Code = aecConfig),
    'thinking=true without budget rejected');
  Req := TCompletionRequest.New('').WithMaxTokens(8);
  Check(TryBad(Req, Code) and (Code = aecConfig), 'empty model rejected');
  Req := TCompletionRequest.New('m').WithMaxTokens(8);
  Req.ResponseSchemaJson := '{"type":"object"}';
  Check(TryBad(Req, Code) and (Code = aecConfig),
    'structured output deferred to v1.1');
end;

procedure TestEncodeToolChoiceW6;
var
  Req: TCompletionRequest;
  Doc: IJsonDocument;
begin
  Req := TCompletionRequest.New('m').WithMaxTokens(16)
    .WithTools(TToolSpecArray.Create(WSpec('f', 'd', '{}')));

  Doc := JsonParse(EncodeAnthropicRequest(
    Req.WithToolChoice(tcmAuto), False));
  CheckEqual('auto',
    Doc.Root.Get('tool_choice').Get('type').AsStr.ToString, 'auto type');

  Doc := JsonParse(EncodeAnthropicRequest(
    Req.WithToolChoice(tcmRequired), False));
  CheckEqual('any',
    Doc.Root.Get('tool_choice').Get('type').AsStr.ToString,
    'required maps to any');

  Doc := JsonParse(EncodeAnthropicRequest(
    Req.WithToolChoice(tcmNamed, 'f'), False));
  CheckEqual('tool',
    Doc.Root.Get('tool_choice').Get('type').AsStr.ToString, 'named type');
  CheckEqual('f',
    Doc.Root.Get('tool_choice').Get('name').AsStr.ToString, 'named tool');

  { unset 不上送（哨兵纪律）}
  Doc := JsonParse(EncodeAnthropicRequest(Req, False));
  Check(not Doc.Root.ObjectHas('tool_choice'), 'unset absent');
end;

procedure TestEncodeNoneOmitsToolsW6;
var
  ReqBase: TCompletionRequest;
  Doc: IJsonDocument;
begin
  ReqBase := TCompletionRequest.New('m').WithMaxTokens(16)
    .WithTools(TToolSpecArray.Create(WSpec('f', 'd', '{}')));

  { tcmNone：省略 tools 字段转译等价禁用（Q-A9 备注）}
  Doc := JsonParse(EncodeAnthropicRequest(
    ReqBase.WithToolChoice(tcmNone), False));
  Check(not Doc.Root.ObjectHas('tools'), 'none omits tools field');
  Check(not Doc.Root.ObjectHas('tool_choice'),
    'none emits no tool_choice key');

  { 对照：同请求 auto 时 tools 在场 }
  Doc := JsonParse(EncodeAnthropicRequest(
    ReqBase.WithToolChoice(tcmAuto), False));
  Check(Doc.Root.ObjectHas('tools'), 'control: tools present with auto');
end;

procedure TestEncodeRejectsW6;
var
  Code: TAgentErrorCode;
  Req: TCompletionRequest;

  function TryBad(const AReq: TCompletionRequest;
    out ACode: TAgentErrorCode): Boolean;
  begin
    Result := False;
    try
      EncodeAnthropicRequest(AReq, False);
    except
      on E: EAgentError do
      begin
        ACode := E.ErrorCode;
        Result := True;
      end;
    end;
  end;

begin
  Req := TCompletionRequest.New('m').WithMaxTokens(8)
    .WithResponseSchema('not json');
  Check(TryBad(Req, Code) and (Code = aecConfig),
    'schema fail-fast on anthropic regardless of payload');

  Req := TCompletionRequest.New('m').WithMaxTokens(8)
    .WithToolChoice(tcmNamed);
  Check(TryBad(Req, Code) and (Code = aecConfig),
    'named without name rejected');

  Req := TCompletionRequest.New('m').WithMaxTokens(8)
    .WithToolChoice(tcmRequired);
  Check(TryBad(Req, Code) and (Code = aecConfig),
    'tool choice with empty tools rejected');
end;

procedure TestEncodeImageSources;
var
  Req: TCompletionRequest;
  Doc: IJsonDocument;
  Src: TJsonValue;

  function EncodeWithImage(const AUrl: string): Boolean;
  begin
    Req := TCompletionRequest.New('m').WithMaxTokens(16);
    SetLength(Req.Messages, 1);
    Req.Messages[0] := Default(TMessage);
    Req.Messages[0].Role := mrUser;
    SetLength(Req.Messages[0].Parts, 1);
    Req.Messages[0].Parts[0] := Default(TPart);
    Req.Messages[0].Parts[0].Kind := pkImage;
    Req.Messages[0].Parts[0].ImageUrl := AUrl;
    try
      Doc := JsonParse(EncodeAnthropicRequest(Req, False));
      Result := not Doc.HasError;
    except
      on E: EAgentError do
        Result := False;
    end;
  end;

begin
  Check(EncodeWithImage('data:image/png;base64,aGk='), 'png data uri ok');
  Src := Doc.Root.Get('messages').ArrayGet(0).Get('content')
    .ArrayGet(0).Get('source');
  Check(Src.Get('type').AsStr.ToString = 'base64', 'base64 source kind');
  CheckEqual('image/png', Src.Get('media_type').AsStr.ToString, 'mime kept');
  CheckEqual('aGk=', Src.Get('data').AsStr.ToString, 'payload kept');

  Check(EncodeWithImage('https://cdn.example/x.jpg'), 'https url ok');
  Check(Doc.Root.Get('messages').ArrayGet(0).Get('content').ArrayGet(0)
    .Get('source').Get('type').AsStr.ToString = 'url', 'url source kind');

  Check(not EncodeWithImage('data:image/svg+xml;base64,PGI+'),
    'mime outside whitelist rejected');
  Check(not EncodeWithImage('file:///etc/passwd'),
    'neither http nor data rejected');
end;

const
  CBodyFull =
    '{"id":"msg_01","type":"message","role":"assistant",' +
    '"model":"claude-m-2024","container":{"x":1},' +
    '"content":[{"type":"text","text":"Hi there"},' +
    '{"type":"thinking","thinking":"thought hard","signature":"sig9"},' +
    '{"type":"tool_use","id":"toolu_9","name":"weather",' +
    '"input":{"city":"上海"}}],' +
    '"stop_reason":"tool_use","stop_sequence":null,' +
    '"usage":{"input_tokens":12,"output_tokens":34,' +
    '"cache_read_input_tokens":3,"cache_creation_input_tokens":5}}';

procedure TestDecodeNonStreamFull;
var
  M: TMessage;
  I: Integer;
  HasThink, HasTool: Boolean;
begin
  DecodeAnthropicResponse(CBodyFull, M, nil);
  CheckEqual('msg_01', M.Id, 'id');
  CheckEqual('claude-m-2024', M.Model, 'model');
  CheckEqual('Hi there', MessageText(M), 'text');
  Check(M.FinishReason = frToolCalls, 'stop_reason mapped');

  for I := 0 to High(M.Parts) do
  begin
    if M.Parts[I].Kind = pkThinking then
    begin
      HasThink := True;
      CheckEqual('thought hard', M.Parts[I].Text, 'thinking payload');
      CheckEqual('sig9', M.Parts[I].Signature,
        'Q-A3 signature passthrough');
    end;
    if M.Parts[I].Kind = pkToolCall then
    begin
      HasTool := True;
      CheckEqual('toolu_9', M.Parts[I].ToolCallId, 'tool id');
      CheckEqual('weather', M.Parts[I].ToolName, 'tool name');
      CheckEqual('{"city":"上海"}', M.Parts[I].ArgumentsJson,
        'input object serialized');
    end;
  end;
  Check(HasThink, 'thinking block -> thinking part');
  Check(HasTool, 'tool_use block -> tool part');

  CheckEqual(Int64(12), M.Usage.InputTokens, 'input tokens');
  CheckEqual(Int64(34), M.Usage.OutputTokens, 'output tokens');
  CheckEqual(Int64(3), M.Usage.CacheReadInputTokens, 'cache read mapped');
  CheckEqual(Int64(5), M.Usage.CacheWriteInputTokens,
    'cache creation mapped as write');
  Check(M.Usage.Known, 'usage known');
  Check(Pos('"container"', M.ExtraJson) > 0,
    'root unknown key captured');
end;

procedure TestDecodeUnmappedStopAndBlock;
var
  M: TMessage;
  Cap: TCapturingLogger;             { 具体类型：断言 Count 用 }
  Log: ILogger;                      { 接口持有：引用计数负责释放 }
begin
  Cap := TCapturingLogger.Create;
  Log := Cap;
  DecodeAnthropicResponse(
    '{"id":"u","model":"m","content":[' +
    '{"type":"server_tool_use","x":1},' +
    '{"type":"text","text":"partial"}],' +
    '"stop_reason":"weird_stop","usage":{}}', M, Log);
  Check(M.FinishReason = frNone, 'unknown stop_reason -> zero value');
  Check(Pos('"agent.unmapped.stop_reason":"weird_stop"',
    M.ExtraJson) > 0, 'unmapped stop preserved under reserved key');
  Check(Pos('"agent.unmapped.content_block_type":"server_tool_use"',
    M.ExtraJson) > 0, 'unmapped block preserved under reserved key');
  CheckEqual('partial', MessageText(M),
    'known blocks survive unmapped siblings');
  Check(Cap.Count >= 2, 'warn on both unmapped kinds');
end;

procedure TestDecodeViolations;
var
  M: TMessage;
  SnippetOk: Boolean;

  function TryBad(const ABody: string; out ASnippet: Boolean): Boolean;
  begin
    Result := False;
    ASnippet := False;
    try
      DecodeAnthropicResponse(ABody, M, nil);
    except
      on E: EAgentError do
        if E.ErrorCode = aecProtocol then
        begin
          Result := True;
          ASnippet := E.RawBodySnippet <> '';
        end;
    end;
  end;

begin
  Check(TryBad('not json', SnippetOk) and SnippetOk,
    'malformed json is protocol with snippet');
  Check(TryBad('{"type":"error","error":{"type":"api_error",'+
    '"message":"boom"}}', SnippetOk),
    'error envelope on success response violates');
  Check(TryBad('{"id":"x"}', SnippetOk), 'missing content array violates');
  Check(TryBad('{"content":[{"type":"tool_use","id":"t","name":"f"}]}',
    SnippetOk), 'tool_use without input violates');
  Check(TryBad('{"content":[],"stop_reason":42}', SnippetOk),
    'non-string stop_reason violates');
end;

function Ev(const AData: string): TWireSSEEvent;
begin
  Result := Default(TWireSSEEvent);
  Result.Data := AData;
end;

function EvN(const AName, AData: string): TWireSSEEvent;
begin
  Result := Default(TWireSSEEvent);
  Result.Event := AName;
  Result.Data := AData;
end;

procedure AppendAllDeltas(var ADst: TStreamDeltaArray;
  const ASrc: TStreamDeltaArray);
var
  I: Integer;
begin
  for I := 0 to High(ASrc) do
  begin
    SetLength(ADst, Length(ADst) + 1);
    ADst[High(ADst)] := ASrc[I];
  end;
end;

procedure FeedDec(D: IAgentWireDecoder; const AEvent, AData: string;
  var AAll: TStreamDeltaArray);
var
  Arr: TStreamDeltaArray;
begin
  D.DecodeEvent(EvN(AEvent, AData), Arr);
  AppendAllDeltas(AAll, Arr);
end;

procedure TestDecoderSequence;
var
  D: IAgentWireDecoder;
  All, Fin: TStreamDeltaArray;
  M: TMessage;
  Misused: Boolean;
begin
  D := NewAnthropicWireDecoder(nil);
  All := nil;
  FeedDec(D, 'message_start',
    '{"type":"message_start","message":{"id":"msg_1","model":"cm",' +
    '"usage":{"input_tokens":10,"cache_read_input_tokens":2,' +
    '"cache_creation_input_tokens":3}}}', All);
  FeedDec(D, 'content_block_start',
    '{"type":"content_block_start","index":0,' +
    '"content_block":{"type":"text","text":""}}', All);
  FeedDec(D, 'content_block_delta',
    '{"type":"content_block_delta","index":0,' +
    '"delta":{"type":"text_delta","text":"He"}}', All);
  FeedDec(D, 'content_block_stop',
    '{"type":"content_block_stop","index":0}', All);
  FeedDec(D, 'content_block_start',
    '{"type":"content_block_start","index":1,' +
    '"content_block":{"type":"thinking","thinking":""}}', All);
  FeedDec(D, 'content_block_delta',
    '{"type":"content_block_delta","index":1,' +
    '"delta":{"type":"thinking_delta","thinking":"th"}}', All);
  FeedDec(D, 'content_block_delta',
    '{"type":"content_block_delta","index":1,' +
    '"delta":{"type":"signature_delta","signature":"sig1"}}', All);
  FeedDec(D, 'content_block_stop',
    '{"type":"content_block_stop","index":1}', All);
  FeedDec(D, 'content_block_start',
    '{"type":"content_block_start","index":2,"content_block":' +
    '{"type":"tool_use","id":"call_9","name":"weather","input":{}}}', All);
  FeedDec(D, 'content_block_delta',
    '{"type":"content_block_delta","index":2,' +
    '"delta":{"type":"input_json_delta","partial_json":"{\"city\""}}', All);
  FeedDec(D, 'content_block_delta',
    '{"type":"content_block_delta","index":2,' +
    '"delta":{"type":"input_json_delta","partial_json":":\"上海\"}"}}', All);
  FeedDec(D, 'content_block_stop',
    '{"type":"content_block_stop","index":2}', All);
  FeedDec(D, 'message_delta',
    '{"type":"message_delta","delta":{"stop_reason":"tool_use"},' +
    '"usage":{"output_tokens":77}}', All);
  CheckEqual(Integer(8), Integer(Length(All)),
    'message_delta stashes only (no delta yet)');

  FeedDec(D, 'message_stop', '{"type":"message_stop"}', All);
  Check(All[0].Kind = sdkEnvelope, 'envelope at message_start');
  CheckEqual('msg_1', All[0].MessageId, 'envelope id');
  CheckEqual('cm', All[0].Model, 'envelope model');
  Check(All[1].Kind = sdkTextDelta, 'text delta second');
  Check(All[2].Kind = sdkThinkingDelta, 'thinking delta');
  CheckEqual('th', All[2].TextDelta, 'thinking payload');
  Check(All[3].Kind = sdkThinkingDelta, 'signature rides thinking kind');
  CheckEqual('', All[3].TextDelta, 'empty text with signature');
  CheckEqual('sig1', All[3].Signature, 'Q-A3 stream signature passthrough');
  Check(All[4].Kind = sdkToolCallStart,
    'anthropic announces at content_block_start');
  CheckEqual('call_9', All[4].ToolCallId, 'start id');
  CheckEqual('weather', All[4].ToolName, 'start name immediate');
  CheckEqual(Integer(2), All[4].ToolIndex, 'start index from wire');
  Check(All[5].Kind = sdkToolCallDelta, 'args fragment one');
  CheckEqual('{"city"', All[5].ArgumentsDelta, 'fragment payload');
  Check(All[6].Kind = sdkToolCallDelta, 'args fragment two');
  Check(All[7].Kind = sdkToolCallEnd, 'block stop closes tool slot');
  Check(All[8].Kind = sdkFinish, 'finish synthesized at message_stop');
  Check(All[8].FinishReason = frToolCalls, 'stashed stop_reason applied');
  Check(All[9].Kind = sdkUsage, 'Q-A2 usage synthesized last');
  CheckEqual(Int64(10), All[9].Usage.InputTokens, 'input from start');
  CheckEqual(Int64(77), All[9].Usage.OutputTokens, 'output from delta');
  CheckEqual(Int64(2), All[9].Usage.CacheReadInputTokens, 'cache read');
  CheckEqual(Int64(3), All[9].Usage.CacheWriteInputTokens, 'cache write');
  CheckEqual(Integer(10), Integer(Length(All)), 'no stray deltas');

  FoldDeltas(All, M);
  CheckEqual('He', MessageText(M), 'folded text');
  CheckEqual('{"city":"上海"}', M.Parts[2].ArgumentsJson,
    'fold reassembles fragmented args');

  D.Finalize(Fin);
  CheckEqual(Integer(0), Integer(Length(Fin)),
    'complete trajectory finalizes empty');
  D.Finalize(Fin);
  CheckEqual(Integer(0), Integer(Length(Fin)), 'finalize idempotent');
  Misused := False;
  try
    D.DecodeEvent(EvN('ping', '"k"'), Fin);
  except
    on Ex: EAgentMisuse do
      Misused := True;
  end;
  Check(Misused, 'decode after finalize is misuse');
end;

procedure TestPingAndUnknownEventsSkipped;
var
  D: IAgentWireDecoder;
  Arr, All: TStreamDeltaArray;
begin
  D := NewAnthropicWireDecoder(nil);
  Arr := nil;
  D.DecodeEvent(EvN('ping', '"keepalive"'), Arr);
  CheckEqual(Integer(0), Integer(Length(Arr)), 'ping skipped');
  D.DecodeEvent(EvN('unknown_future_event', 'not json at all'), Arr);
  CheckEqual(Integer(0), Integer(Length(Arr)),
    'unknown event warn-skipped, data never parsed');
  FeedDec(D, 'message_start',
    '{"type":"message_start","message":{"id":"p","model":"m"}}', All);
  Check(Length(All) >= 1, 'stream flows after skips');
end;

procedure TestMidStreamError;
var
  D: IAgentWireDecoder;
  All, Arr, Fin: TStreamDeltaArray;
  M: TMessage;
begin
  D := NewAnthropicWireDecoder(nil);
  All := nil;
  FeedDec(D, 'message_start',
    '{"type":"message_start","message":{"id":"e1","model":"m",' +
    '"usage":{"input_tokens":4}}}', All);
  FeedDec(D, 'error',
    '{"type":"error","error":{"type":"overloaded_error",' +
    '"message":"Overloaded"}}', All);
  Check(All[High(All)].Kind = sdkError, 'error event -> sdkError');
  Check(All[High(All)].Error.Code = aecServer,
    'overloaded maps to server class');
  Check(All[High(All)].Error.Retryable, 'server class retryable');
  Check(Pos('[overloaded_error]', All[High(All)].Error.Message) > 0,
    'raw type preserved in message');
  Check(Pos('Overloaded', All[High(All)].Error.Message) > 0,
    'vendor message preserved');
  Check(Pos('"agent.unmapped', All[0].UnmappedJson +
    All[High(All)].UnmappedJson) = 0,
    'known error type never captured as unmapped');

  { FDead：错误后到帧弃置（含普通帧），Finalize 静默（不再叠加归因）}
  Arr := nil;
  FeedDec(D, 'content_block_delta',
    '{"type":"content_block_delta","index":0,' +
    '"delta":{"type":"text_delta","text":"ghost"}}', Arr);
  CheckEqual(Integer(0), Integer(Length(Arr)), 'frames after error dropped');
  D.Finalize(Fin);
  CheckEqual(Integer(0), Integer(Length(Fin)), 'finalize silent after death');

  FoldDeltas(All, M);
  Check(M.FinishReason = frNone, 'dead stream folds without finish');
end;

procedure TestUnmappedErrTypeCaptured;
var
  D2: IAgentWireDecoder;
  All2: TStreamDeltaArray;
begin
  { 未知 type 以 aecServer 兜底，原始 type 走保留键保真（独立解码器：
    错误后解码器已死是 §0 设计行为，不能在同一流上喂第二种错误）}
  D2 := NewAnthropicWireDecoder(nil);
  All2 := nil;
  FeedDec(D2, 'error',
    '{"type":"error","error":{"type":"mystery_error","message":"???"}}',
    All2);
  CheckEqual(Integer(1), Integer(Length(All2)), 'single sdkError delta');
  Check(All2[0].Kind = sdkError, 'kind sdkError');
  Check(All2[0].Error.Code = aecServer, 'unknown type falls back server');
  Check(Pos('[mystery_error]', All2[0].Error.Message) > 0,
    'raw type prefixed in message');
  Check(Pos('"agent.unmapped.error_type":"mystery_error"',
    All2[0].UnmappedJson) > 0, 'unmapped error type captured on delta');
end;

procedure TestQA8TruncationFailClosed;
var
  D: IAgentWireDecoder;
  All, Fin: TStreamDeltaArray;
  Raised, Snippet: Boolean;
begin
  { 从未见 message_start：Finalize 即抛 }
  D := NewAnthropicWireDecoder(nil);
  Raised := False;
  Snippet := False;
  try
    D.Finalize(Fin);
  except
    on E: EAgentError do
      if E.ErrorCode = aecProtocol then
      begin
        Raised := True;
        Snippet := Pos('<stream>', E.RawBodySnippet) > 0;
      end;
  end;
  Check(Raised and Snippet, 'empty decoder finalize fails closed (Q-A8)');

  { start 而无 stop：截断答案绝不合成完整消息 }
  D := NewAnthropicWireDecoder(nil);
  All := nil;
  FeedDec(D, 'message_start',
    '{"type":"message_start","message":{"id":"t","model":"m"}}', All);
  FeedDec(D, 'content_block_start',
    '{"type":"content_block_start","index":0,' +
    '"content_block":{"type":"text","text":""}}', All);
  FeedDec(D, 'content_block_delta',
    '{"type":"content_block_delta","index":0,' +
    '"delta":{"type":"text_delta","text":"half an answer"}}', All);
  Raised := False;
  try
    D.Finalize(Fin);
  except
    on E: EAgentError do
      Raised := E.ErrorCode = aecProtocol;
  end;
  Check(Raised, 'truncated trajectory fails closed');
end;

{ W7：ReasoningEffort 无厂商参数——忽略 + warn 日志（Q-A5 同规则），
  补全不受影响 }
procedure TestReasoningEffortIgnoredW7;
var
  T: TScriptedTransport;
  Opts: TAnthropicOptions;
  P: IAgentProvider;
  M: TMessage;
  Cap: TCapturingLogger;
  Log: ILogger;
  I: Integer;
  Found: Boolean;
begin
  T := TScriptedTransport.Create;
  T.ProviderName := 'anthropic';
  T.Add(ScriptResp(200, CBodyFull));
  Cap := TCapturingLogger.Create;
  Log := Cap;
  Opts := TAnthropicOptions.New('');
  Opts.Common.ApiKey := 'ak-test';
  Opts.Common.Model := 'fallback-m';
  Opts.Common.Transport := T;
  Opts.Common.Logger := Log;
  P := NewAnthropicProvider(Opts);
  M := P.Complete(TCompletionRequest.New('').WithMaxTokens(128)
    .WithUserText('go').WithReasoningEffort(reHigh));
  CheckEqual('Hi there', MessageText(M), 'complete unaffected by ignore');
  Found := False;
  for I := 0 to Cap.Count - 1 do
    if Pos('reasoning_effort', Cap.Lines[I]) > 0 then
      Found := True;
  Check(Found, 'warn logged mentioning reasoning_effort');
end;

function CountSub(const AHay, ANeedle: string): Integer;
var
  P, LFrom: Integer;
begin
  Result := 0;
  LFrom := 1;
  while LFrom <= Length(AHay) do
  begin
    P := Pos(ANeedle, Copy(AHay, LFrom, Length(AHay)));
    if P = 0 then
      Break;
    Inc(Result);
    LFrom := LFrom + P + Length(ANeedle) - 1;
  end;
end;

{ W10（WIRE-MAPPINGS §2.6）：ccmAuto 三断点放置——tools 尾恒定/system
  数组形态恒定/末条消息尾块；ccmUnset 字节零变化 }
procedure TestEncodeCacheControlW10;
var
  LFull, LSparse: TJsonText;
begin
  LFull := EncodeAnthropicRequest(TCompletionRequest.New('claude-x')
    .WithMaxTokens(64)
    .WithSystem('sys-prefix')
    .WithTools([WSpec('t1', 'd1', '{"type":"object"}'),
                WSpec('t2', 'd2', '{"type":"object"}')])
    .WithUserText('round one')
    .WithCacheControl(ccmAuto), False);
  { 三载体齐备：恰好 3 个标记 }
  CheckEqual(3, CountSub(LFull, '"cache_control"'),
    'three markers for tools+system+tail');
  Check(Pos('"system":[{"type":"text","text":"sys-prefix"', LFull) > 0,
    'system switches to block array form when caching');
  Check(Pos('"name":"t2","description":"d2","input_schema":' +
    '{"type":"object"},"cache_control":{"type":"ephemeral"}}', LFull) > 0,
    'last tool carries marker');
  Check(Pos('"text":"round one","cache_control":{"type":"ephemeral"' +
    '}}]', LFull) > 0,
    'tail message final block carries marker');

  { 无 tools 无 system：仅消息尾一处标记 }
  LSparse := EncodeAnthropicRequest(TCompletionRequest.New('claude-x')
    .WithMaxTokens(64).WithUserText('solo')
    .WithCacheControl(ccmAuto), False);
  CheckEqual(1, CountSub(LSparse, '"cache_control"'),
    'sparse request marks message tail only');
end;

procedure TestEncodeCacheUnsetByteStableW10;
var
  LReq: TCompletionRequest;
begin
  LReq := TCompletionRequest.New('claude-x').WithMaxTokens(64)
    .WithSystem('sys-prefix')
    .WithTools([WSpec('t1', 'd1', '{"type":"object"}')])
    .WithUserText('hello');
  Check(Pos('cache_control',
    EncodeAnthropicRequest(LReq, False)) = 0,
    'ccmUnset emits no cache markers (v1 byte stability)');
  Check(Pos('"system":"sys-prefix"',
    EncodeAnthropicRequest(LReq, False)) > 0,
    'ccmUnset keeps system string form');
end;

procedure TestEncodeCacheEmptyTailSkippedW10;
var
  M: TMessage;
  LReq: TCompletionRequest;
begin
  { 末条消息无 parts：无块可附着，整请求零标记 }
  M := Default(TMessage);
  M.Role := mrUser;
  LReq := TCompletionRequest.New('claude-x').WithMaxTokens(64)
    .WithCacheControl(ccmAuto);
  SetLength(LReq.Messages, 1);
  LReq.Messages[0] := M;
  CheckEqual(0, CountSub(EncodeAnthropicRequest(LReq, False),
    '"cache_control"'),
    'empty tail message yields zero markers');
end;

procedure TestProviderCompleteEndToEnd;
var
  T: TScriptedTransport;
  Opts: TAnthropicOptions;
  P: IAgentProvider;
  M: TMessage;
  LReq: TWireRequest;
  Doc: IJsonDocument;
  I: Integer;
  FoundKey, FoundVer: Boolean;
begin
  T := TScriptedTransport.Create;
  T.ProviderName := 'anthropic';
  T.Add(ScriptResp(200, CBodyFull));
  Opts := TAnthropicOptions.New('');
  Opts.Common.ApiKey := 'ak-test';
  Opts.Common.Model := 'fallback-m';
  Opts.Common.Transport := T;
  P := NewAnthropicProvider(Opts);
  CheckEqual('anthropic', P.GetName, 'provider name');
  M := P.Complete(
    TCompletionRequest.New('').WithMaxTokens(128).WithUserText('go'));
  CheckEqual('Hi there', MessageText(M), 'complete roundtrip');

  LReq := T.LastRequest;
  CheckEqual('https://api.anthropic.com/v1/messages', LReq.Url,
    'default url join');
  FoundKey := False;
  FoundVer := False;
  for I := 0 to High(LReq.Headers) do
  begin
    if (LReq.Headers[I].Name = 'x-api-key') and
      (LReq.Headers[I].Value = 'ak-test') then
      FoundKey := True;
    if (LReq.Headers[I].Name = 'anthropic-version') and
      (LReq.Headers[I].Value = CANTHROPIC_VERSION_DEFAULT) then
      FoundVer := True;
  end;
  Check(FoundKey, 'x-api-key header');
  Check(FoundVer, 'anthropic-version header default');
  Doc := JsonParse(LReq.BodyJson);
  Check(not Doc.HasError, 'wire body parses');
  CheckEqual('fallback-m', Doc.Root.Get('model').AsStr.ToString,
    'model falls back to options');
  CheckEqual(Int64(128), Doc.Root.Get('max_tokens').AsInt,
    'max_tokens from request');
  Check(not Doc.Root.ObjectHas('stream'), 'complete path non-stream body');
end;

procedure TestProviderStreamEndToEnd;
var
  Ch: TStringArray;
  Resp: TScriptResponse;
  T: TScriptedTransport;
  Opts: TAnthropicOptions;
  P: IAgentProvider;
  C: IAgentCompletion;
  D: TStreamDelta;
  Text: string;
  Misuse: Boolean;
begin
  { 命名局部持有脚本数组：内联临时经嵌套调用传参在部分 FPC 代码生成
    路径下生命周期不可靠（lane 提交记录有案），测试一律用显式变量 }
  Ch := TStringArray.Create(
    'event: message_start'#10'data: {"type":"message_start","message":' +
    '{"id":"s1","model":"sm","usage":{"input_tokens":3}}}'#10#10,
    'event: content_block_start'#10'data: {"type":"content_block_start",' +
    '"index":0,"content_block":{"type":"text","text":""}}'#10#10,
    'event: ping'#10'data: "ka"'#10#10,
    'event: content_block_delta'#10'data: {"type":"content_block_delta",' +
    '"index":0,"delta":{"type":"text_delta","text":"hel"}}'#10#10,
    'event: content_block_delta'#10'data: {"type":"content_block_delta",' +
    '"index":0,"delta":{"type":"text_delta","text":"lo"}}'#10#10,
    'event: content_block_stop'#10'data: {"type":"content_block_stop",' +
    '"index":0}'#10#10,
    'event: message_delta'#10'data: {"type":"message_delta","delta":' +
    '{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}'#10#10,
    'event: message_stop'#10'data: {"type":"message_stop"}'#10#10);
  Resp := ScriptChunks(Ch);
  T := TScriptedTransport.Create;
  T.ProviderName := 'anthropic';
  T.Add(Resp);
  Opts := TAnthropicOptions.New('sm');
  Opts.Common.ApiKey := 'k';
  Opts.Common.Transport := T;
  P := NewAnthropicProvider(Opts);
  C := P.Stream(TCompletionRequest.New('sm').WithMaxTokens(32));

  Misuse := False;
  try
    C.GetMessage;
  except
    on E: EAgentMisuse do
      Misuse := True;
  end;
  Check(Misuse, 'GetMessage before EOF misuse');

  Text := '';
  while C.NextDelta(D) do
    if D.Kind = sdkTextDelta then
      Text := Text + D.TextDelta;
  CheckEqual('hello', Text, 'streamed text across chunks, ping skipped');
  Check(MessageText(C.GetMessage) = 'hello', 'folded at EOF');
  Check(C.GetUsage.Known, 'synthesized usage known');
  CheckEqual(Int64(3), C.GetUsage.InputTokens, 'stream input tokens');
  CheckEqual(Int64(5), C.GetUsage.OutputTokens, 'stream output tokens');
  Check(Pos('/v1/messages', T.LastRequest.Url) > 0,
    'stream opened messages url');
end;

procedure TestProviderUpstreamError;
var
  Resp: TScriptResponse;
  T: TScriptedTransport;
  Opts: TAnthropicOptions;
  P: IAgentProvider;
  Hit: Boolean;
begin
  Resp := Default(TScriptResponse);
  Resp.Status := 400;
  Resp.BodyText :=
    '{"type":"error","error":{"type":"invalid_request_error",' +
    '"message":"bad key"}}';
  Resp.RaiseUpstream := True;
  T := TScriptedTransport.Create;
  T.ProviderName := 'anthropic';       { 与生产 transport 同源归因 }
  T.Add(Resp);
  Opts := TAnthropicOptions.New('m');
  Opts.Common.ApiKey := 'k';
  Opts.Common.Transport := T;
  P := NewAnthropicProvider(Opts);
  Hit := False;
  try
    P.Complete(TCompletionRequest.New('m').WithMaxTokens(16));
  except
    on E: EAgentError do
      Hit := (E.ErrorCode = aecInvalidRequest) and (E.Provider = 'anthropic');
  end;
  Check(Hit, 'upstream 400 classified with provider attribution');
end;

procedure TestProviderHonorsCancellationAtBoundary;
var
  T: TScriptedTransport;
  Opts: TAnthropicOptions;
  P: IAgentProvider;
  Tok: IAsyncCancellationToken;
  Cancelled: Boolean;
begin
  { 同步 transport 的诚实边界：已取消令牌在起点拒绝（§5）}
  T := TScriptedTransport.Create;
  Opts := TAnthropicOptions.New('m');
  Opts.Common.ApiKey := 'k';
  Opts.Common.Transport := T;
  P := NewAnthropicProvider(Opts);
  Tok := CreateCancellationToken;
  Tok.Cancel;
  Cancelled := False;
  try
    P.Complete(TCompletionRequest.New('m').WithMaxTokens(8), Tok);
  except
    on E: EAgentCancelled do
      Cancelled := True;
  end;
  Check(Cancelled, 'cancelled token rejects at entry');
  CheckEqual(Integer(0), T.ServedCount, 'no wire request issued');
end;

procedure TestUrlAndOptionsDefaults;
begin
  CheckEqual('https://api.anthropic.com/v1/messages', BuildAnthropicUrl(''),
    'default base');
  CheckEqual('https://proxy.corp/v1/messages',
    BuildAnthropicUrl('https://proxy.corp/v1/'), 'prejoined /v1');
  CheckEqual('https://gw.io/ant/v1/messages',
    BuildAnthropicUrl('https://gw.io/ant/'), 'reverse-proxy prefix');
  CheckEqual(Int64(10000), TAnthropicOptions.New('x').Common.ConnectTimeoutMs,
    'connect default');
  CheckEqual(Int64(300000), TAnthropicOptions.New('x').Common.TotalTimeoutMs,
    'total default');
  CheckEqual('2023-06-01', TAnthropicOptions.New('x').AnthropicVersion,
    'version pin default');
end;

procedure TestFromEnv;
var
  P: IAgentProvider;
begin
  if not HasEnv(CANTHROPIC_ENV_API_KEY) then
  begin
    P := NewAnthropicProviderFromEnv;
    Check(P = nil, 'missing env -> nil, never silent fallback');
  end;
  SetEnv(CANTHROPIC_ENV_API_KEY, 'env-k');
  SetEnv(CANTHROPIC_ENV_MODEL, 'env-m');
  UnsetEnv(CANTHROPIC_ENV_BASE_URL);
  P := NewAnthropicProviderFromEnv;
  Check(P <> nil, 'env assembly succeeds');
  if P <> nil then
    CheckEqual('anthropic', P.GetName, 'env provider name');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.provider.anthropic');
  T.Test('encode minimal snapshot', @TestEncodeMinimalSnapshot);
  T.Test('encode full matrix', @TestEncodeFullMatrix);
  T.Test('encode system merge', @TestEncodeSystemMerge);
  T.Test('encode rejects', @TestEncodeRejects);
  T.Test('encode tool choice W6', @TestEncodeToolChoiceW6);
  T.Test('encode none omits tools W6', @TestEncodeNoneOmitsToolsW6);
  T.Test('encode rejects W6', @TestEncodeRejectsW6);
  T.Test('reasoning effort ignored W7', @TestReasoningEffortIgnoredW7);
  T.Test('encode cache control W10', @TestEncodeCacheControlW10);
  T.Test('encode cache unset byte stable W10',
    @TestEncodeCacheUnsetByteStableW10);
  T.Test('encode cache empty tail skipped W10',
    @TestEncodeCacheEmptyTailSkippedW10);
  T.Test('encode image sources', @TestEncodeImageSources);
  T.Test('decode non-stream full', @TestDecodeNonStreamFull);
  T.Test('decode unmapped stop and block', @TestDecodeUnmappedStopAndBlock);
  T.Test('decode violations', @TestDecodeViolations);
  T.Test('decoder sequence', @TestDecoderSequence);
  T.Test('ping and unknown events skipped', @TestPingAndUnknownEventsSkipped);
  T.Test('mid stream error', @TestMidStreamError);
  T.Test('unmapped error type captured', @TestUnmappedErrTypeCaptured);
  T.Test('q-a8 truncation fail closed', @TestQA8TruncationFailClosed);
  T.Test('provider complete e2e', @TestProviderCompleteEndToEnd);
  T.Test('provider stream e2e', @TestProviderStreamEndToEnd);
  T.Test('provider upstream error', @TestProviderUpstreamError);
  T.Test('provider honors cancellation at boundary',
    @TestProviderHonorsCancellationAtBoundary);
  T.Test('url and options defaults', @TestUrlAndOptionsDefaults);
  T.Test('from env', @TestFromEnv);
  if not T.Run then Halt(1);
end.
