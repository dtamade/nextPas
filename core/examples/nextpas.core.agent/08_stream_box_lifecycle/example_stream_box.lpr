program example_stream_box;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.agent.base,
  nextpas.core.agent.intf,
  nextpas.core.agent.streambox,
  nextpas.core.agent.provider.fake;

{ 08 流式盒生命周期：sdkThinkingDelta 思考中→首 TextDelta 生成中 + Lock+Done+id 失配丢弃
  契约锚点：LIFECYCLE.md §1/§8 + PERFORMANCE.md §7.2 + ARCHITECTURE.md §4
  运行：make -C core/examples/nextpas.core.agent/08_stream_box_lifecycle run
  离线可跑：fake provider 脚本回放思考+正文交错流 }

const
  CSCRIPT =
    '[{"deltas":[' +
    '{"kind":"thinking_delta","text":"先分析用户意图..."},' +
    '{"kind":"thinking_delta","text":"再检查工具可用性"},' +
    '{"kind":"text_delta","text":"你好，"},' +
    '{"kind":"text_delta","text":"这是流式回答。"},' +
    '{"kind":"finish","reason":"stop"},' +
    '{"kind":"usage","in":14,"out":9}]}]';

type
  // 复用 nextpas.core.agent.streambox 的 TAgentStreamBox（经 nextpas.core 沉淀，
  // 零直接依赖 SyncObjs；本例保留别名以贴近 PERFORMANCE §7.2 的 TAiStreamBox 命名）
  TStreamBox = TAgentStreamBox;

var
  LProv: IAgentProvider;
  LReq: TCompletionRequest;
  LComp: IAgentCompletion;
  LD: TStreamDelta;
  LBox: TStreamBox;
  LThinking, LAnswer: string;
  LInThinking: Boolean;
  LStale: TStreamDelta;
  LMsg: TMessage;
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
  LReq.Messages[0].Parts[0].Text := '演示思考与流式盒';

  // 模拟每次 Stream() 自增 id，下游回调携带 id 做失配丢弃
  LBox := TStreamBox.Create(42);
  try
    LComp := LProv.Stream(LReq);
    LInThinking := False;
    while LComp.NextDelta(LD) do
    begin
      // 投递至盒：id 匹配才入队（真实 TUI 侧工作线程→UI 线程跨线程投递）
      LBox.Push(LD, 42);
      case LD.Kind of
        sdkThinkingDelta:
          begin
            if not LInThinking then begin LInThinking := True; WriteLn('[思考中]'); end;
            LThinking := LThinking + LD.TextDelta;
            WriteLn('  thinking chunk: ', LD.TextDelta);
          end;
        sdkTextDelta:
          begin
            if LInThinking then begin LInThinking := False; WriteLn('[生成中]'); end;
            LAnswer := LAnswer + LD.TextDelta;
            Write('[chunk] ', LD.TextDelta); WriteLn;
          end;
        sdkFinish: WriteLn('[finish] reason=', Ord(LD.FinishReason));
        sdkUsage: if LD.Usage.Known then WriteLn('[usage] in=', LD.Usage.InputTokens, ' out=', LD.Usage.OutputTokens);
      else
        ;
      end;
    end;
    LBox.MarkDone;

    // 迟到写仲裁演示：旧 id 的增量到达盒时直接丢弃
    LStale := Default(TStreamDelta);
    LStale.Kind := sdkTextDelta;
    LStale.TextDelta := 'stale should be dropped';
    LBox.Push(LStale, 41); // id 失配 → 丢弃
    WriteLn('stale dropped: ', not LBox.TryPop(LStale) or (LStale.TextDelta <> 'stale should be dropped'));

    // 盒内剩余增量按序消费（已终态不再接收）
    while LBox.TryPop(LD) do
      WriteLn('box pop: ', Ord(LD.Kind));

    // EOF 后 fold 最终消息就绪（LIFECYCLE §1 Terminal 幂等）
    LMsg := LComp.GetMessage;
    WriteLn('---');
    WriteLn('folded final: ', MessageText(LMsg));
    WriteLn('folded == streamed: ', MessageText(LMsg) = LAnswer);
  finally
    LBox.Free;
  end;
end.
