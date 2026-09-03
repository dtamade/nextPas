{**
 * nextpas.core.agent.pricing — 纯策略计费：零IO，纯函数无堆分配。
 *
 * T1.4 成本口径：token 计费估算，整数 μUSD 四舍五入，无浮点（CUsageUnknown 按 0 计）。
 * T1.1 纯策略（Phase1 T1.1）：TModelPricing/EstimateCost 整数μUSD
 *   (prompt*per1k+500) div 1000 + (completion*per1k*rate+5000) div 10000
 *   同源 tk888.billing.pas:22,212；TPassthroughPricing/ImageTierOf max-edge
 *   ≤1024→1000 ≤2048→2000 else 4000 含 2048x2048→2000 特判 billing:470。
 *}

unit nextpas.core.agent.pricing;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.agent.base,
  nextpas.core.agent.textutil;

const
  CDefaultPromptPer1k      = 2500;  { μUSD / 1k prompt tokens }
  CDefaultCompletionPer1k  = 10000; { μUSD / 1k completion tokens }

type
  TModelPricing = record
    Per1kPromptUsd: Int64;
    Per1kCompletionUsd: Int64;
    RateDenominator: Int64;
  end;

  TPassthroughPricing = record
    FlatCostUsd6: Int64;
  end;

{ ── T1.1 纯策略 ── }
function EstimateCost(const APricing: TModelPricing;
  APromptTokens, ACompletionTokens: Int64;
  ARateMultiplier: Int64 = 10000): Int64; overload; inline;

function ImageTierOf(const AWidth, AHeight: Int64): Int64; inline;

{ ── T1.4 估算成本（μUSD）：四舍五入到千，无浮点；未知字段按 0 计 ── }
function EstimateCost(const AUsage: TTokenUsage): Int64; overload;
function EstimateCost(const AUsage: TTokenUsage;
  APromptPer1k, ACompletionPer1k: Int64): Int64; overload;
function EstimateCost(APromptTokens, ACompletionTokens: Int64): Int64; overload;
function EstimateCost(APromptTokens, ACompletionTokens: Int64;
  APromptPer1k, ACompletionPer1k: Int64): Int64; overload;

{ 文本→token 粗估（~4 字符/token，loop 预算同口径，F-M16）：空串→0 }
function AgentEstimateTokens(const S: string): Int64; inline;
function AgentEstimateTokensFromMessage(const AMsg: TMessage): Int64; inline;

implementation

{ ── T1.1 ── }

function EstimateCost(const APricing: TModelPricing;
  APromptTokens, ACompletionTokens: Int64; ARateMultiplier: Int64): Int64; inline;
var
  LRate: Int64;
  LPromptCost: Int64;
  LCompletionCost: Int64;
begin
  if APromptTokens < 0 then APromptTokens := 0;
  if ACompletionTokens < 0 then ACompletionTokens := 0;
  LRate := ARateMultiplier;
  if LRate <= 0 then
    LRate := 10000;
  LPromptCost := (APromptTokens * APricing.Per1kPromptUsd + 500) div 1000;
  LCompletionCost :=
    (ACompletionTokens * APricing.Per1kCompletionUsd * LRate + 5000) div 10000;
  Result := LPromptCost + LCompletionCost;
end;

function ImageTierOf(const AWidth, AHeight: Int64): Int64; inline;
var
  LMax: Int64;
begin
  LMax := AWidth;
  if AHeight > LMax then
    LMax := AHeight;
  if LMax <= 1024 then
    Result := 1000
  else if LMax <= 2048 then
    Result := 2000
  else
    Result := 4000;
end;

{ ── T1.4 ── }

function EstimateCost(APromptTokens, ACompletionTokens: Int64): Int64; inline;
begin
  Result := EstimateCost(APromptTokens, ACompletionTokens,
    CDefaultPromptPer1k, CDefaultCompletionPer1k);
end;

function EstimateCost(APromptTokens, ACompletionTokens: Int64;
  APromptPer1k, ACompletionPer1k: Int64): Int64; inline;
begin
  if APromptTokens < 0 then
    APromptTokens := 0;
  if ACompletionTokens < 0 then
    ACompletionTokens := 0;
  Result := (APromptTokens * APromptPer1k + 500) div 1000
          + (ACompletionTokens * ACompletionPer1k + 500) div 1000;
end;

function EstimateCost(const AUsage: TTokenUsage): Int64; inline;
begin
  Result := EstimateCost(AUsage, CDefaultPromptPer1k, CDefaultCompletionPer1k);
end;

function EstimateCost(const AUsage: TTokenUsage;
  APromptPer1k, ACompletionPer1k: Int64): Int64; inline;
var
  LIn, LOut: Int64;
begin
  LIn := AUsage.InputTokens;
  LOut := AUsage.OutputTokens;
  if LIn = CUsageUnknown then
    LIn := 0;
  if LOut = CUsageUnknown then
    LOut := 0;
  if (AUsage.CacheReadInputTokens <> CUsageUnknown) and (AUsage.CacheReadInputTokens > 0) then
    LIn := LIn + AUsage.CacheReadInputTokens;
  if (AUsage.CacheWriteInputTokens <> CUsageUnknown) and (AUsage.CacheWriteInputTokens > 0) then
    LIn := LIn + AUsage.CacheWriteInputTokens;
  if (AUsage.ReasoningTokens <> CUsageUnknown) and (AUsage.ReasoningTokens > 0) then
    LOut := LOut + AUsage.ReasoningTokens;
  Result := EstimateCost(LIn, LOut, APromptPer1k, ACompletionPer1k);
end;

function AgentEstimateTokens(const S: string): Int64; inline;
begin
  Result := nextpas.core.agent.textutil.AgentEstimateTokens(S);
end;

function AgentEstimateTokensFromMessage(const AMsg: TMessage): Int64; inline;
begin
  Result := nextpas.core.agent.textutil.AgentEstimateTokens(MessageText(AMsg));
end;

end.
