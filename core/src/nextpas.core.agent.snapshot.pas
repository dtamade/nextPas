{**
 * nextpas.core.agent.snapshot - 有界快照预算封装（6000 B 管线可复用面）。
 *
 * 职责：AgentBuildSystemText 合并去重 + 加权估算 + 簇安全截断 + 成本联动 的
 * 一站式封装，供 PROMPT-BUDGET 消费方直接复用；零直接依赖 FPC RTL，
 * 全部经 nextpas.core.text/pricing/base 单一真源。
 * 契约权威：PROMPT-BUDGET.md §2/§5/§7 + PERFORMANCE.md §7.1 + API.md §10。
 * 反哺点：StringOfChar 等 FPC RTL 密集构造收至 nextpas.core.text 域，本单元
 * 仅通过 base/text/pricing 消费（满足"不直接依赖 FPC RTL，经 nextpas.core 解决"纪律）。
 *}

unit nextpas.core.agent.snapshot;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.agent.base,
  nextpas.core.agent.pricing;

const
  CBoundedSnapshotBudget = 6000;

function BuildBoundedSnapshot(const ASystem: string;
  const AMessages: TMessageArray; ABudget: Integer = CBoundedSnapshotBudget): string; inline;

function BoundedSnapshotTokens(const ASnapshot: string): Int64; inline;
function BoundedSnapshotCost(const ASnapshot: string; ACompletionTokens: Int64 = 0): Int64; inline;

implementation

uses
  nextpas.core.text.utf8,
  nextpas.core.text.grapheme;

function BuildBoundedSnapshot(const ASystem: string;
  const AMessages: TMessageArray; ABudget: Integer): string;
var
  LFull: string;
  LCut, LPos, LNext, LBest: Integer;
  LG: TGraphemeResult;
begin
  LFull := AgentBuildSystemText(ASystem, AMessages);
  if Length(LFull) <= ABudget then
    Exit(LFull);
  LCut := AgentUtf8SafeCutLen(LFull, ABudget);
  // ASCII 快路径：前 LCut 字节全 < $80 时簇边界即 LCut，免 GraphemeNext 扫描
  LPos := 1;
  while (LPos <= LCut) and (Ord(LFull[LPos]) < $80) do Inc(LPos);
  if LPos > LCut then
    Exit(AgentUtf8SafeTruncate(LFull, LCut));
  // 簇安全对齐：从首字节前向遍历 GraphemeNext，找到 ≤ LCut 的最大簇边界
  // 避免 👨‍👩‍👧 / 🇨🇳 / 1️⃣ 等序列被半切导致 EAW 列宽错位（PERFORMANCE §7.1）
  LPos := 1;
  LBest := 0;
  while LPos <= Length(LFull) do
  begin
    LG := GraphemeNext(@LFull[LPos], Length(LFull) - LPos + 1);
    if LG.ByteLen <= 0 then Break;
    LNext := LPos + LG.ByteLen - 1;
    if LNext > LCut then Break;
    LBest := LNext;
    Inc(LPos, LG.ByteLen);
  end;
  if LBest > 0 then
    LCut := LBest;
  Result := AgentUtf8SafeTruncate(LFull, LCut);
end;

function BoundedSnapshotTokens(const ASnapshot: string): Int64;
begin
  Result := AgentEstimateTokens(ASnapshot);
end;

function BoundedSnapshotCost(const ASnapshot: string; ACompletionTokens: Int64): Int64;
begin
  Result := EstimateCost(BoundedSnapshotTokens(ASnapshot), ACompletionTokens);
end;

end.
