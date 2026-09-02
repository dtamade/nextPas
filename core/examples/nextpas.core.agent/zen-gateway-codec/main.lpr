program zen_gateway_codec;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.fold,
  nextpas.core.agent.provider.openai.responses,
  nextpas.core.json;

{ Zen Gateway Codec: D13 pure codec as library, not gateway.
  Build TCompletionRequest with System+Tools+Thinking, EncodeResponsesRequest
  straight to wire (no HTTP), print JSON, then decode via
  DecodeResponsesResponse / NewResponsesWireDecoder fold. Offline, no network.

  Run: make -C core/examples/nextpas.core.agent/zen-gateway-codec run }

function TextOfParts(const AMsg: TMessage): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AMsg.Parts) do
    if AMsg.Parts[I].Kind = pkText then
      Result := Result + AMsg.Parts[I].Text;
end;

function ThinkingOf(const AMsg: TMessage): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AMsg.Parts) do
    if AMsg.Parts[I].Kind = pkThinking then
      Result := Result + AMsg.Parts[I].Text;
end;

var
  LReq: TCompletionRequest;
  LSpec: TToolSpec;
  LJson: TJsonText;
  LRespBody: TJsonText;
  LMsg: TMessage;
  LDecoder: IAgentWireDecoder;
  LEvt: TWireSSEEvent;
  LDeltas, LFinal: TStreamDeltaArray;
  I: Integer;
  LBuild: TAssistantBuild;
begin
  { 1. Build request: System + Tools + Thinking (builder chain). }
  LSpec := Default(TToolSpec);
  LSpec.Name := 'lookup';
  LSpec.Description := 'lookup knowledge by query';
  LSpec.ParametersJson :=
    '{"type":"object","required":["q"],' +
    '"properties":{"q":{"type":"string"}}}';

  LReq := TCompletionRequest.New('gpt-4o')
    .WithSystem('You are a zen gateway — answer with clarity.')
    .WithUserText('Explain codec vs gateway in one sentence.');
  LReq.Tools := [LSpec];
  LReq.Thinking := tsTrue;
  LReq.ThinkingBudgetTokens := 1024;
  LReq.ReasoningEffort := reMedium;

  WriteLn('--- EncodeResponsesRequest (no HTTP) ---');
  LJson := EncodeResponsesRequest(LReq, False);
  WriteLn(LJson);
  WriteLn;

  WriteLn('BuildResponsesUrl: ', BuildResponsesUrl(''));
  WriteLn('BuildResponsesUrl(proxy): ', BuildResponsesUrl('https://proxy.example/v1'));
  WriteLn;

  { 2. Decode non-stream response body straight. }
  WriteLn('--- DecodeResponsesResponse (non-stream) ---');
  LRespBody :=
    '{"id":"resp_zen_1","model":"gpt-4o","status":"completed",' +
    '"output":[' +
      '{"type":"message","role":"assistant","content":[' +
        '{"type":"output_text","text":"Codec is pure wire translation; gateway is process + policy."}' +
      ']},' +
      '{"type":"reasoning","summary":[{"type":"summary_text","text":"thinking: gateway adds routing, codec does not"}]}' +
    '],' +
    '"usage":{"input_tokens":18,"output_tokens":12,"output_tokens_details":{"reasoning_tokens":4}}}';
  DecodeResponsesResponse(LRespBody, LMsg);
  WriteLn('decoded text: ', TextOfParts(LMsg));
  WriteLn('decoded thinking: ', ThinkingOf(LMsg));
  WriteLn('finish=', Ord(LMsg.FinishReason), ' usage in=', LMsg.Usage.InputTokens,
    ' out=', LMsg.Usage.OutputTokens,
    ' reasoning=', LMsg.Usage.ReasoningTokens);
  WriteLn;

  { 3. Decode stream via NewResponsesWireDecoder + Fold. }
  WriteLn('--- NewResponsesWireDecoder (stream fold) ---');
  LDecoder := NewResponsesWireDecoder;

  LEvt.Event := 'response.created';
  LEvt.Data := '{"type":"response.created","response":{"id":"resp_zen_1","model":"gpt-4o"}}';
  LDecoder.DecodeEvent(LEvt, LDeltas);
  for I := 0 to High(LDeltas) do
    if LDeltas[I].Kind = sdkEnvelope then
      WriteLn('[envelope] id=', LDeltas[I].MessageId, ' model=', LDeltas[I].Model);

  LEvt.Event := 'response.output_text.delta';
  LEvt.Data := '{"type":"response.output_text.delta","delta":"Zen is "}';
  LDecoder.DecodeEvent(LEvt, LDeltas);
  for I := 0 to High(LDeltas) do
    if LDeltas[I].Kind = sdkTextDelta then
      WriteLn('[delta] ', LDeltas[I].TextDelta);

  LEvt.Data := '{"type":"response.output_text.delta","delta":"codec as library."}';
  LDecoder.DecodeEvent(LEvt, LDeltas);
  for I := 0 to High(LDeltas) do
    if LDeltas[I].Kind = sdkTextDelta then
      WriteLn('[delta] ', LDeltas[I].TextDelta);

  LEvt.Event := 'response.completed';
  LEvt.Data :=
    '{"type":"response.completed","response":{' +
    '"id":"resp_zen_1","status":"completed",' +
    '"usage":{"input_tokens":18,"output_tokens":12}}}';
  LDecoder.DecodeEvent(LEvt, LDeltas);
  for I := 0 to High(LDeltas) do
    case LDeltas[I].Kind of
      sdkUsage: WriteLn('[usage] in=', LDeltas[I].Usage.InputTokens);
      sdkFinish: WriteLn('[finish] reason=', Ord(LDeltas[I].FinishReason));
    else
      ;
    end;

  { Finalize also returns any trailing deltas (here empty). Collect all via
    manual fold of synthetic history for demo completeness. }
  LDecoder.Finalize(LFinal);
  WriteLn('finalize deltas=', Length(LFinal));

  { Full fold from ground-truth deltas (library fold is single truth). }
  LBuild := TAssistantBuild.Create;
  try
    LEvt.Event := 'response.created';
    LEvt.Data := '{"type":"response.created","response":{"id":"resp_zen_1","model":"gpt-4o"}}';
    LDecoder := NewResponsesWireDecoder;
    LDecoder.DecodeEvent(LEvt, LDeltas);
    for I := 0 to High(LDeltas) do LBuild.FoldDelta(LDeltas[I]);
    LEvt.Event := 'response.output_text.delta';
    LEvt.Data := '{"type":"response.output_text.delta","delta":"Zen is codec as library."}';
    LDecoder.DecodeEvent(LEvt, LDeltas);
    for I := 0 to High(LDeltas) do LBuild.FoldDelta(LDeltas[I]);
    LEvt.Event := 'response.completed';
    LEvt.Data := '{"type":"response.completed","response":{"status":"completed","usage":{"input_tokens":18,"output_tokens":12}}}';
    LDecoder.DecodeEvent(LEvt, LDeltas);
    for I := 0 to High(LDeltas) do LBuild.FoldDelta(LDeltas[I]);
    LDecoder.Finalize(LFinal);
    for I := 0 to High(LFinal) do LBuild.FoldDelta(LFinal[I]);
    LMsg := LBuild.Finish;
    WriteLn('folded final: "', TextOfParts(LMsg), '"');
  finally
    LBuild.Free;
  end;

  WriteLn('done (D13 codec is library, not gateway)');
end.
