program example_streaming;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.fake;

{ 02 真流式：增量消费补全（API.md §2 Stream 路径）。
  NextDelta 拉动式排水——厂商 socket 到一段即产出一段，不等到 EOF；
  GetMessage 在 EOF 后返回内部折叠完成的最终消息（D1 唯一折叠实现）。
  零网络：生产 fake provider 按脚本逐段回放。

  运行：make -C core/examples/nextpas.core.agent/02_streaming run }

const
  CSCRIPT =
    '[{"deltas":[' +
    '{"kind":"text_delta","text":"Build systems decay "},' +
    '{"kind":"text_delta","text":"unless exercised. "},' +
    '{"kind":"text_delta","text":"Tests are exercise."},' +
    '{"kind":"finish","reason":"stop"},' +
    '{"kind":"usage","in":9,"out":11}]}]';

var
  LProv: IAgentProvider;
  LReq: TCompletionRequest;
  LComp: IAgentCompletion;
  LDelta: TStreamDelta;
  LMsg: TMessage;
  LFull: string;
  I: Integer;
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
  LReq.Messages[0].Parts[0].Text := 'Say something wise.';

  { Stream 返回完成对象；取消可经第二参令牌全程贯通 }
  LComp := LProv.Stream(LReq);
  while LComp.NextDelta(LDelta) do
    case LDelta.Kind of
      sdkTextDelta:
        begin
          Write('[chunk] ', LDelta.TextDelta);
          WriteLn;
        end;
      sdkFinish:
        WriteLn('[finish] reason=', Ord(LDelta.FinishReason));
      sdkUsage:
        if LDelta.Usage.Known then
          WriteLn('[usage] in=', LDelta.Usage.InputTokens,
            ' out=', LDelta.Usage.OutputTokens);
      else
        ;                              { 其余增量类型本例不展示 }
    end;

  { EOF 之后：fold 完成的最终消息与用量就绪 }
  LMsg := LComp.GetMessage;
  LFull := '';
  for I := 0 to High(LMsg.Parts) do
    if LMsg.Parts[I].Kind = pkText then
      LFull := LFull + LMsg.Parts[I].Text;
  WriteLn('---');
  WriteLn('folded final: ', LFull);
end.
