{**
 * nextpas.core.agent.loop.budget - 预算纯函数：估算/预警/累计。
 *
 * 职责：OutUsed 跟踪、80% 预警阈值、MaxOutputTokens 达限判定、
 * EstimateTokensFallback（优先 IAgentTokenCounter 探测，失败回落
 * AgentEstimateTokens 单一真源，避免预警延迟 F-M16）。
 * 契约权威：API.md §6；ARCHITECTURE §5；pricing 纯策略复用。
 * 分层：仅依赖 types + base / intf / pricing / textutil，无循环。
 *}

unit nextpas.core.agent.loop.budget;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.agent.base,
  nextpas.core.agent.intf;

function LoopEstimateTokensFallback(const AProvider: IAgentProvider;
  const AText: string): Int64;

function LoopShouldWarn(AOutUsed, AMaxOutputTokens: Int64;
  AWarned: Boolean): Boolean; inline;

function LoopBudgetExhausted(AOutUsed, AMaxOutputTokens: Int64): Boolean; inline;

procedure LoopInitUsageUnknown(var AUsage: TTokenUsage); inline;

procedure LoopAccumulateUsage(var ATotal: TTokenUsage;
  const AInc: TTokenUsage);

function LoopAddOutUsed(AOutUsed: Int64; const AMsg: TMessage;
  const AProvider: IAgentProvider): Int64;

function LoopCostForMessage(const AMsg: TMessage): Int64; overload;
function LoopCostForMessage(const AMsg: TMessage;
  const AProvider: IAgentProvider): Int64; overload;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.text.builder,
  nextpas.core.agent.pricing,
  nextpas.core.agent.textutil;

function LoopEstimateTokensFallback(const AProvider: IAgentProvider;
  const AText: string): Int64;
var
  LCounter: IAgentTokenCounter;
  LReq: TCompletionRequest;
begin
  if Supports(AProvider, IAgentTokenCounter, LCounter) then
  try
    LReq := TCompletionRequest.New('').WithUserText(AText);
    Result := LCounter.CountTokens(LReq);
    Exit;
  except
    // 探测失败回落自有估算（API.md §3.3 诚实边界）
  end;
  Result := AgentEstimateTokens(AText);
end;

function LoopShouldWarn(AOutUsed, AMaxOutputTokens: Int64;
  AWarned: Boolean): Boolean; inline;
begin
  if (AMaxOutputTokens <= 0) or AWarned then
    Exit(False);
  // 溢出钳制：与 hedge.pas High div 1e6 同款守卫，AOutUsed*5 溢出即视为已超 80% 预警阈
  if AOutUsed > High(Int64) div 5 then
    Exit(True);
  if AMaxOutputTokens > High(Int64) div 4 then
    Exit(AOutUsed > (AMaxOutputTokens div 5) * 4);
  Result := AOutUsed * 5 > AMaxOutputTokens * 4;
end;

function LoopBudgetExhausted(AOutUsed, AMaxOutputTokens: Int64): Boolean; inline;
begin
  Result := (AMaxOutputTokens > 0) and (AOutUsed >= AMaxOutputTokens);
end;

procedure LoopInitUsageUnknown(var AUsage: TTokenUsage); inline;
begin
  AgentInitUsageUnknown(AUsage);
end;

procedure LoopAccumulateUsage(var ATotal: TTokenUsage;
  const AInc: TTokenUsage);

  function Sum2(AAcc, AIncV: Int64): Int64; inline;
  begin
    if AIncV = CUsageUnknown then
      Exit(AAcc);
    if AAcc = CUsageUnknown then
      Exit(AIncV);
    Result := AAcc + AIncV;
  end;

begin
  if not AInc.Known then
    Exit;
  ATotal.InputTokens := Sum2(ATotal.InputTokens, AInc.InputTokens);
  ATotal.OutputTokens := Sum2(ATotal.OutputTokens, AInc.OutputTokens);
  ATotal.CacheReadInputTokens :=
    Sum2(ATotal.CacheReadInputTokens, AInc.CacheReadInputTokens);
  ATotal.CacheWriteInputTokens :=
    Sum2(ATotal.CacheWriteInputTokens, AInc.CacheWriteInputTokens);
  ATotal.ReasoningTokens :=
    Sum2(ATotal.ReasoningTokens, AInc.ReasoningTokens);
end;

function LoopAddOutUsed(AOutUsed: Int64; const AMsg: TMessage;
  const AProvider: IAgentProvider): Int64;
var
  LText: string;
  I, LTotal: Integer;
  LB: IStringBuilder;
begin
  if AMsg.Usage.Known and (AMsg.Usage.OutputTokens <> CUsageUnknown) then
    Exit(AOutUsed + AMsg.Usage.OutputTokens);
  LText := MessageText(AMsg);
  if LText <> '' then
    Exit(AOutUsed + LoopEstimateTokensFallback(AProvider, LText));
  LTotal := 0;
  for I := 0 to High(AMsg.Parts) do
    if AMsg.Parts[I].Kind = pkToolCall then
      Inc(LTotal, Length(AMsg.Parts[I].ToolName) + Length(AMsg.Parts[I].ArgumentsJson));
  if LTotal = 0 then
    Exit(AOutUsed + LoopEstimateTokensFallback(AProvider, 'tool_call'));
  LB := MakeStringBuilder(LTotal);
  for I := 0 to High(AMsg.Parts) do
    if AMsg.Parts[I].Kind = pkToolCall then
    begin
      LB.AppendStr(AMsg.Parts[I].ToolName);
      LB.AppendStr(AMsg.Parts[I].ArgumentsJson);
    end;
  Result := AOutUsed + LoopEstimateTokensFallback(AProvider, LB.ToString);
end;

function LoopCostForMessage(const AMsg: TMessage): Int64;
begin
  Result := LoopCostForMessage(AMsg, nil);
end;

function LoopCostForMessage(const AMsg: TMessage;
  const AProvider: IAgentProvider): Int64;
var
  LText: string;
  I, LTotal: Integer;
  LB: IStringBuilder;
begin
  if AMsg.Usage.Known then
    Exit(EstimateCost(AMsg.Usage));
  LText := MessageText(AMsg);
  if LText <> '' then
    Exit(EstimateCost(0, LoopEstimateTokensFallback(AProvider, LText)));
  LTotal := 0;
  for I := 0 to High(AMsg.Parts) do
    if AMsg.Parts[I].Kind = pkToolCall then
      Inc(LTotal, Length(AMsg.Parts[I].ToolName) + Length(AMsg.Parts[I].ArgumentsJson));
  if LTotal = 0 then
    Exit(EstimateCost(0, LoopEstimateTokensFallback(AProvider, 'tool_call')));
  LB := MakeStringBuilder(LTotal);
  for I := 0 to High(AMsg.Parts) do
    if AMsg.Parts[I].Kind = pkToolCall then
    begin
      LB.AppendStr(AMsg.Parts[I].ToolName);
      LB.AppendStr(AMsg.Parts[I].ArgumentsJson);
    end;
  Result := EstimateCost(0, LoopEstimateTokensFallback(AProvider, LB.ToString));
end;

end.
