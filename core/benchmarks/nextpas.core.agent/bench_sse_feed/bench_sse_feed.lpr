program bench_sse_feed;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.agent.base,
  nextpas.core.agent.sse,
  nextpas.core.fs;

{ bench_sse_feed（TESTING.md §4）：16 MiB SSE 流按 32 KiB 块 Feed。
  主张（PERFORMANCE §1/§2）：O(bytes) 单遍解析、MB/s 与 http.sse 同数量级；
  行缓冲初始 4 KiB 倍增至上限，块边界任意切割（帧可跨块断裂）。

  流内容为通用 SSE 帧（event+data），总字节恰为 CChunks × CChunkBytes。 }

const
  CChunkBytes = 32 * 1024;
  CChunks = 512;                       { 512 × 32 KiB = 16 MiB }
  CTotalBytes = Int64(CChunkBytes) * CChunks;

var
  GBig: string;                        { 预生成的连续 SSE 字节流 }
  GEvents: Int64;                      { 排水事件计数防死代码消除 }

{ 单帧 ~256 字节：event 行 + data 行 + 空行 }
procedure BuildStream;
var
  LFrame: string;
  LPos, LLimit, LCopyLen: Integer;
begin
  LFrame :=
    'event: message' + #10 +
    'data: {"seq":0,"author":"bench","text":"' +
    '012345678901234567890123456789012345678901234567890123456789' +
    '012345678901234567890123456789012345678901234567890123456789' +
    '0123456789012345678"}' + #10 + #10;

  SetLength(GBig, CTotalBytes);
  LPos := 1;
  while LPos <= CTotalBytes do
  begin
    LLimit := LPos + Length(LFrame) - 1;
    if LLimit > CTotalBytes then
      LLimit := CTotalBytes;
    LCopyLen := LLimit - LPos + 1;
    Move(LFrame[1], GBig[LPos], LCopyLen);
    LPos := LLimit + 1;
  end;
  { 尾部若截断半帧，由 Finish 的宽容收口处理（Q-O4）——正是真实分块形态 }
end;

procedure BenchFeed16MiB(const ACtx: IBenchContext);
var
  LParser: TSSEParser;
  LOff, LLen: Integer;
  LEvt: TWireSSEEvent;
begin
  LParser := TSSEParser.Create;
  try
    for LOff := 0 to CChunks - 1 do
    begin
      LLen := CChunkBytes;
      if (LOff + 1) * CChunkBytes > Length(GBig) then
        LLen := Length(GBig) - LOff * CChunkBytes;
      LParser.Feed(TByteSpan.Create(@GBig[LOff * CChunkBytes + 1], LLen));
      while LParser.PopEvent(LEvt) do
        Inc(GEvents);                  { 拉动式排水 }
    end;
    LParser.Finish;
    while LParser.PopEvent(LEvt) do
      Inc(GEvents);
  finally
    LParser.Free;
  end;
  ACtx.SetBytes(CTotalBytes);
end;

var
  LResults: IBenchResults;
begin
  BuildStream;
  LResults := TBenchSuite.Create('agent')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('sse-feed/16MiB-32KiB-chunks', @BenchFeed16MiB)
    .Run;
  WriteLn('events drained: ', GEvents);
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-agent-sse-feed.json');
end.
