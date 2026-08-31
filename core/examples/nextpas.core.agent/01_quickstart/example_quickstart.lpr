program example_quickstart;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.fake,
  nextpas.core.json;

{ 01 快速上手：非流式一次补全（API.md §2 Complete 路径）。
  本示例走生产 fake provider（脚本回放、零网络）演示最小调用面；
  换真实后端只需把 NewFakeProvider 换成 NewOpenAIProvider /
  NewAnthropicProvider（或 *FromEnv 工厂），其余代码一字不改。

  运行：make -C core/examples/nextpas.core.agent/01_quickstart run }

const
  { 脚本格式见 provider.fake 单元头注释：JSON 数组，每项一个虚拟响应 }
  CSCRIPT =
    '[{"deltas":[' +
    '{"kind":"text_delta","text":"Shanghai tomorrow: cloudy, "},' +
    '{"kind":"text_delta","text":"18-24C, light rain after dusk."},' +
    '{"kind":"finish","reason":"stop"},' +
    '{"kind":"usage","in":12,"out":21}]}]';

var
  LProv: IAgentProvider;
  LReq: TCompletionRequest;
  LReply: TMessage;

function TextOfParts(const AMsg: TMessage): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AMsg.Parts) do
    if AMsg.Parts[I].Kind = pkText then
      Result := Result + AMsg.Parts[I].Text;
end;

begin
  LProv := NewFakeProvider(CSCRIPT);

  LReq := Default(TCompletionRequest);
  LReq.Model := 'fake-model';
  SetLength(LReq.Messages, 1);
  LReq.Messages[0] := Default(TMessage);
  LReq.Messages[0].Role := mrUser;
  SetLength(LReq.Messages[0].Parts, 1);
  LReq.Messages[0].Parts[0] := Default(TPart);
  LReq.Messages[0].Parts[0].Kind := pkText;
  LReq.Messages[0].Parts[0].Text := 'What is the weather in Shanghai?';

  { 同步一次补全：成功即返回完整 assistant 消息；失败抛 EAgentError
    （错误分类见 docs/agent/ERRORS.md）——直线代码，无需轮询 }
  LReply := LProv.Complete(LReq);

  WriteLn('reply: ', TextOfParts(LReply));
  if LReply.Usage.Known then
    WriteLn('usage: in=', LReply.Usage.InputTokens,
      ' out=', LReply.Usage.OutputTokens);
end.
