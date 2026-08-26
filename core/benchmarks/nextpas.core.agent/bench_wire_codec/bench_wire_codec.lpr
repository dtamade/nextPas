program bench_wire_codec;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.agent.base,
  nextpas.core.agent.provider.anthropic,
  nextpas.core.agent.provider.openai.responses,
  nextpas.core.fs;

{ bench_wire_codec（W9/W10 收口基准补齐）：wire 词表 ↔ 协议方言的纯编解码
  进程内开销——Responses 请求编码与混合输出解码（W9）、Anthropic 编码
  unset 与 ccmAuto 打点对照（W10 断点标记放置成本）。仓库基准禁止触公网
  LLM API（TESTING 铁律）；夹具全部本地构造，无 transport 参与 }

const
  CTurns = 8;          { user/assistant 往返数 → 16 条历史消息 }
  CTools = 5;          { 随请求工具数 }
  CReasonItems = 4;    { decode 体：reasoning 输出项 }
  CCallItems = 4;      { decode 体：function_call 输出项 }
  CMsgItems = 6;       { decode 体：assistant 文本输出项 }

var
  GPad: string;
  GReqBase: TCompletionRequest;    { system + 16 消息（尾轮工具对）+ 5 工具，
                                     MaxTokens 就位（anthropic 强制必填）}
  GReqCache: TCompletionRequest;   { 同形 + ccmAuto }
  GRespBody: TJsonText;            { 合成 Responses 非流式体：14 输出项 }
  GSink: Integer;
  GOutMsg: TMessage;

function Pad(AI: Integer): string;
begin
  { ~150 字节确定性填充，贴近真实正文片段尺寸且含非 ASCII }
  Result := Copy(GPad, 1, Length(GPad) - 3) + IntToStr(AI) + '要点。';
end;

procedure InitFixtures;
var
  I: Integer;
  LSpecs: TToolSpecArray;
  LSpec: TToolSpec;
  LMsg: TMessage;
  LPart: TPart;
begin
  GPad := '';
  for I := 0 to 11 do
    GPad := GPad + 'Lorem-ipsum-填充-';

  SetLength(LSpecs, CTools);
  for I := 0 to CTools - 1 do
  begin
    LSpec := Default(TToolSpec);
    LSpec.Name := 'tool_' + IntToStr(I);
    LSpec.Description := Pad(I);
    LSpec.ParametersJson :=
      '{"type":"object","properties":{"q":{"type":"string"}},' +
      '"required":["q"]}';

    LSpecs[I] := LSpec;
  end;

  GReqBase := TCompletionRequest.New('bench-model')
    .WithSystem(GPad).WithMaxTokens(4096);
  GReqBase.Tools := LSpecs;
  SetLength(GReqBase.Messages, CTurns * 2);
  for I := 0 to CTurns - 1 do
  begin
    { user 文本轮 }
    LMsg := Default(TMessage);
    LMsg.Role := mrUser;
    LPart := Default(TPart);
    LPart.Kind := pkText;
    LPart.Text := Pad(I) + ' 总结上文并给出下一步建议。';
    SetLength(LMsg.Parts, 1);
    LMsg.Parts[0] := LPart;
    GReqBase.Messages[I * 2] := LMsg;

    if I < CTurns - 1 then
    begin
      { assistant 文本轮 }
      LMsg := Default(TMessage);
      LMsg.Role := mrAssistant;
      LPart := Default(TPart);
      LPart.Kind := pkText;
      LPart.Text := Pad(I + 30);
      SetLength(LMsg.Parts, 1);
      LMsg.Parts[0] := LPart;
      GReqBase.Messages[I * 2 + 1] := LMsg;
    end
    else
    begin
      { 尾轮：assistant 工具调用 + 结果回喂（编码工具分支必经）}
      LMsg := Default(TMessage);
      LMsg.Role := mrAssistant;
      LPart := Default(TPart);
      LPart.Kind := pkToolCall;
      LPart.ToolCallId := 'call_bench';
      LPart.ToolName := 'tool_0';
      LPart.ArgumentsJson := '{"q":"nextpas wire codec bench"}';
      SetLength(LMsg.Parts, 1);
      LMsg.Parts[0] := LPart;
      GReqBase.Messages[I * 2 + 1] := LMsg;

      LMsg := Default(TMessage);
      LMsg.Role := mrTool;
      LPart := Default(TPart);
      LPart.Kind := pkToolResult;
      LPart.ToolCallId := 'call_bench';
      LPart.ResultJson := '{"ok":true,"rows":42,"pad":"' + Copy(GPad, 1, 40) + '"}';
      SetLength(LMsg.Parts, 1);
      LMsg.Parts[0] := LPart;
      GReqBase.Messages[I * 2 + 1] := LMsg;
    end;
  end;

  GReqCache := GReqBase.WithCacheControl(ccmAuto);

  { 合成 Responses 非流式体：reasoning/function_call/message 三类混合 }
  GRespBody :=
    '{"id":"resp_bench","object":"response","model":"m1","status":"completed",' +
    '"usage":{"input_tokens":812,"output_tokens":356,' +
      '"output_tokens_details":{"reasoning_tokens":96},' +
      '"input_tokens_details":{"cached_tokens":512}},' +
    '"output":[';
  for I := 0 to CReasonItems - 1 do
    GRespBody := GRespBody +
      '{"type":"reasoning","id":"rs_' + IntToStr(I) + '","summary":[' +
        '{"type":"summary_text","text":"' + Pad(I + 60) + '"}]},';
  for I := 0 to CCallItems - 1 do
    GRespBody := GRespBody +
      '{"type":"function_call","id":"fc_' + IntToStr(I) + '",'+
        '"call_id":"call_' + IntToStr(I) + '","name":"tool_' + IntToStr(I) +
        '","arguments":"{\"q\":\"' + Copy(GPad, 1, 32) + '\"}"},';
  for I := 0 to CMsgItems - 1 do
  begin
    GRespBody := GRespBody +
      '{"type":"message","role":"assistant","id":"msg_' + IntToStr(I) +
      '","content":[{"type":"output_text","text":"' + Pad(I + 80) + '"}]}';
    if I < CMsgItems - 1 then
      GRespBody := GRespBody + ',';
  end;
  GRespBody := GRespBody + ']}';
end;

procedure BenchResponsesEncode(const ACtx: IBenchContext);
begin
  GSink := GSink + Length(EncodeResponsesRequest(GReqBase, False));
end;

procedure BenchResponsesDecode(const ACtx: IBenchContext);
begin
  DecodeResponsesResponse(GRespBody, GOutMsg);
  GSink := GSink + Length(GOutMsg.Parts);
end;

procedure BenchAnthropicEncodeBase(const ACtx: IBenchContext);
begin
  GSink := GSink + Length(EncodeAnthropicRequest(GReqBase, False));
end;

procedure BenchAnthropicEncodeAuto(const ACtx: IBenchContext);
begin
  GSink := GSink + Length(EncodeAnthropicRequest(GReqCache, False));
end;

var
  LResults: IBenchResults;
  LRBody, LABody: TJsonText;
begin
  InitFixtures;
  { 启动自检：两个编码器必须接受夹具（违例即刻 fail-fast），
    并落定真实体量供文档口径引用 }
  LRBody := EncodeResponsesRequest(GReqBase, False);
  LABody := EncodeAnthropicRequest(GReqBase, False);
  WriteLn('fixture-bytes: responses-decode-body=', Length(GRespBody),
    ' responses-encode-out=', Length(LRBody),
    ' anthropic-encode-base-out=', Length(LABody),
    ' anthropic-encode-auto-out=', Length(EncodeAnthropicRequest(GReqCache, False)));
  LResults := TBenchSuite.Create('agent')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('wire/responses-encode-16msg-5tools', @BenchResponsesEncode)
    .Add('wire/responses-decode-mixed-14items', @BenchResponsesDecode)
    .Add('wire/anthropic-encode-base', @BenchAnthropicEncodeBase)
    .Add('wire/anthropic-encode-ccm-auto', @BenchAnthropicEncodeAuto)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-agent-wire-codec.json');
end.
