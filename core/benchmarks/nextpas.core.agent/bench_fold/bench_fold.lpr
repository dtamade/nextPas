program bench_fold;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.agent.base,
  nextpas.core.agent.fold,
  nextpas.core.fs;

{ bench_fold（TESTING.md §4）：10k delta 折叠总耗时，其中含 50 个工具槽的
  参数片段累积。主张（PERFORMANCE §1）：O(1) 摊许/delta——禁止 per-delta
  SetLength 与 s := s + x 回归；参数片段经 StringBuilder 倍增缓冲。 }

const
  CTextCount = 9750;    { 纯文本 delta 数 }
  CSlotCount = 50;      { 工具槽数 }
  CFragPerSlot = 3;     { 每槽参数片段数 }
  CSlotDeltas = CSlotCount * (2 + CFragPerSlot);
  CTotal = CTextCount + CSlotDeltas;   { = 10000 }

var
  GDeltas: array of TStreamDelta;
  GPad: string;
  GSink: Integer;

procedure InitDeltas;
var
  I, S, F, N: Integer;
begin
  { ~64 字节填充文本，贴近真实正文片段尺寸 }
  GPad := '';
  for I := 0 to 7 do
    GPad := GPad + 'Lorem-ipsum-delta-';
  GPad := Copy(GPad, 1, 60);

  SetLength(GDeltas, CTotal);
  N := 0;
  { 文本流 }
  for I := 0 to CTextCount - 1 do
  begin
    GDeltas[N] := Default(TStreamDelta);
    GDeltas[N].Kind := sdkTextDelta;
    GDeltas[N].TextDelta := GPad;
    Inc(N);
  end;
  { 50 个工具槽：宣告 + 3 段参数片段（~40 字节）+ 收口 }
  for S := 0 to CSlotCount - 1 do
  begin
    GDeltas[N] := Default(TStreamDelta);
    GDeltas[N].Kind := sdkToolCallStart;
    GDeltas[N].ToolIndex := S;
    GDeltas[N].ToolCallId := 'call_' + IntToStr(S);
    GDeltas[N].ToolName := 'tool_' + IntToStr(S);
    Inc(N);
    for F := 0 to CFragPerSlot - 1 do
    begin
      GDeltas[N] := Default(TStreamDelta);
      GDeltas[N].Kind := sdkToolCallDelta;
      GDeltas[N].ToolIndex := S;
      GDeltas[N].ArgumentsDelta :=
        '{"k' + IntToStr(F) + '":"v","pad":"0123456789abcd"}';
      Inc(N);
    end;
    GDeltas[N] := Default(TStreamDelta);
    GDeltas[N].Kind := sdkToolCallEnd;
    GDeltas[N].ToolIndex := S;
    Inc(N);
  end;
end;

procedure BenchFold10k(const ACtx: IBenchContext);
var
  LMsg: TMessage;
begin
  FoldDeltas(GDeltas, LMsg);
  GSink := GSink + Length(LMsg.Parts);
end;

var
  LResults: IBenchResults;
begin
  InitDeltas;
  LResults := TBenchSuite.Create('agent')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('fold/10k-deltas-50-slots', @BenchFold10k)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-agent-fold.json');
end.
