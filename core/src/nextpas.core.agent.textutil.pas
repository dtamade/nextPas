{**
 * nextpas.core.agent.textutil - agent 文本工具薄壳。
 *
 * 职责：UTF-8 安全截断单一真源已反哺至 nextpas.core.text.utf8
 * （UTF8SafeTruncate，门面 TextUTF8SafeTruncate）；本单元仅保留
 * AgentEstimateTokens 估算与兼容转发名（AgentUtf8SafeCutLen/Truncate
 * 为公共 API 冻结名，转发到 text 域单源）。纯函数无状态。
 * 估算精度：~4 char/token 粗估（F-M16 同口径，英文贴近 CJK/代码偏高估安全侧），
 * 基准：PROMPT-BUDGET.md §3 / pricing.EstimateCost；预算/截断路径由 loop.budget
 * 80% 预警 + MaxOutputTokens 达限双阈值校验，探测 IAgentTokenCounter 优先回落本估算。
 * 零拷贝：Length 零分配视图；切分/截断经 text.utf8 单源 BytesCopy。
 *}

unit nextpas.core.agent.textutil;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text;

function AgentUtf8SafeCutLen(const S: string; AMaxBytes: Integer): Integer; inline;
function AgentUtf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;
{ 粗估 ~4 char/token，单一真源；非 inline（预算/截断热路径外，避免 I-Cache 膨胀，基准见 PROMPT-BUDGET.md §3）}
function AgentEstimateTokens(const S: string): Int64;

implementation

function AgentUtf8SafeCutLen(const S: string; AMaxBytes: Integer): Integer; inline;
begin
  Result := nextpas.core.text.TextUTF8SafeCutLen(S, AMaxBytes);
end;

function AgentUtf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;
begin
  Result := nextpas.core.text.TextUTF8SafeTruncate(S, AMaxBytes);
end;

function AgentEstimateTokens(const S: string): Int64;
begin
  // zero-copy: Length 视图零分配；~4 char/token 粗估，安全侧高估，基准 pricing.EstimateCost / PROMPT-BUDGET
  if S = '' then
    Exit(0);
  Result := (Int64(Length(S)) + 3) div 4;
end;

end.
