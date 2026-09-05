{**
 * nextpas.core.agent.pricing — 纯策略计费：零IO，纯函数无堆分配。
 *
 * T1.4 成本口径：token 计费估算，整数 μUSD 四舍五入，无浮点（CUsageUnknown 按 0 计）。
 * T1.1 纯策略（Phase1 T1.1）：TModelPricing/EstimateCost 整数μUSD
 *   (prompt*per1k+500) div 1000 + (completion*per1k*rate+5000) div 10000
 *   同源 tk888.billing.pas:22,212；TPassthroughPricing/ImageTierOf max-edge
 *   ≤1024→1000 ≤2048→2000 else 4000 含 2048x2048→2000 特判 billing:470。
 * C2（2026-09-05）：V1 记录口径冻结（倍率仅 completion 腿，RateDenominator
 *   未读、实现硬编码 10000），标 deprecated；新语义走 EstimateCostV2 /
 *   EstimateCostWithScope + rsTotal（倍率作用整单总额，与 token888
 *   billing §倍率同源），RateDenominator 自 V2 起生效。
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
  CRateDenominator         = 10000; { 1.0x；RateDenominator 自 V2 起生效，<=0 回落此值 }

type
  TModelPricing = record
    Per1kPromptUsd: Int64;
    Per1kCompletionUsd: Int64;
    RateDenominator: Int64; { V1 未读（实现恒 10000）；V2 生效，<=0 回落 CRateDenominator }
  end;

  { 倍率作用域：rsCompletionOnly = V1 冻结语义（仅 completion 腿）；
    rsTotal = V2 / token888 整单总额语义 }
  TRateScope = (rsCompletionOnly, rsTotal);

  TPassthroughPricing = record
    FlatCostUsd6: Int64;
  end;

{ ── T1.1 纯策略（冻结；倍率仅 completion 腿，RateDenominator 未读）── }
function EstimateCost(const APricing: TModelPricing;
  APromptTokens, ACompletionTokens: Int64;
  ARateMultiplier: Int64 = 10000): Int64; overload; inline;
  deprecated 'Use EstimateCostV2 or EstimateCostWithScope(rsTotal); V1 completion-only rate frozen';

{ ── C2 V2：倍率作用整单总额（token888 billing §倍率同源）；RateDenominator 生效 ── }
{ rate<=0 时编译期常量折叠会触发 div 零（const 入参内联求值），故不 inline }
function ApplyRateTotal(ACostUsd6, ARateMultiplier, ARateDenominator: Int64): Int64;
function EstimateCostV2(const APricing: TModelPricing;
  APromptTokens, ACompletionTokens: Int64;
  ARateMultiplier: Int64 = 10000): Int64; overload; inline;
function EstimateCostLegsV2(const APricing: TModelPricing;
  APromptTokens, ACompletionTokens: Int64; ARateMultiplier: Int64;
  out APromptLegUsd6, ACompletionLegUsd6: Int64): Int64;
function EstimateCostWithScope(const APricing: TModelPricing;
  APromptTokens, ACompletionTokens: Int64; ARateMultiplier: Int64;
  AScope: TRateScope): Int64; inline;

function ImageTierOf(const AWidth, AHeight: Int64): Int64; inline;

{ ── T1.4 估算成本（μUSD）：四舍五入到千，无浮点；未知字段按 0 计；
   无倍率（基费腿，与 ApplyRateTotal 组合即 V2 总额口径）── }
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

{ ── T1.1（冻结实现，原样保留）── }

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

{ ── C2 V2：整单总额口径（token888 billing ApplyRateUsd6/TokenCostSaturated 同源）── }

function PricingLegCost(const ATokens, APer1k: Int64): Int64;
var
  LProd: Int64;
begin
  if (ATokens <= 0) or (APer1k <= 0) then
    Exit(0);
  if ATokens > (High(Int64) - 500) div APer1k then
    Exit(High(Int64));
  LProd := ATokens * APer1k + 500;
  Result := LProd div 1000;
end;

function PricingEffectiveDenominator(const APricing: TModelPricing): Int64;
begin
  if APricing.RateDenominator > 0 then
    Result := APricing.RateDenominator
  else
    Result := CRateDenominator;
end;

function ApplyRateTotal(ACostUsd6, ARateMultiplier, ARateDenominator: Int64): Int64;
var
  LHalf: Int64;
  LProd: Int64;
begin
  if ARateMultiplier <= 0 then
    Exit(ACostUsd6);
  if ACostUsd6 <= 0 then
    Exit(0);
  if ARateDenominator <= 0 then
    ARateDenominator := CRateDenominator;
  LHalf := ARateDenominator div 2;
  if ACostUsd6 > (High(Int64) - LHalf) div ARateMultiplier then
    Exit(High(Int64));
  LProd := ACostUsd6 * ARateMultiplier + LHalf;
  Result := LProd div ARateDenominator;
end;

function EstimateCostLegsV2(const APricing: TModelPricing;
  APromptTokens, ACompletionTokens: Int64; ARateMultiplier: Int64;
  out APromptLegUsd6, ACompletionLegUsd6: Int64): Int64;
var
  LBase: Int64;
begin
  APromptLegUsd6 := PricingLegCost(APromptTokens, APricing.Per1kPromptUsd);
  ACompletionLegUsd6 := PricingLegCost(ACompletionTokens, APricing.Per1kCompletionUsd);
  if (APromptLegUsd6 = High(Int64)) or (ACompletionLegUsd6 = High(Int64)) then
    LBase := High(Int64)
  else if APromptLegUsd6 > High(Int64) - ACompletionLegUsd6 then
    LBase := High(Int64)
  else
    LBase := APromptLegUsd6 + ACompletionLegUsd6;
  if LBase = High(Int64) then
    Exit(High(Int64));
  Result := ApplyRateTotal(LBase, ARateMultiplier, PricingEffectiveDenominator(APricing));
end;

function EstimateCostV2(const APricing: TModelPricing;
  APromptTokens, ACompletionTokens: Int64; ARateMultiplier: Int64): Int64; inline;
var
  LPromptLeg, LCompLeg: Int64;
begin
  Result := EstimateCostLegsV2(APricing, APromptTokens, ACompletionTokens,
    ARateMultiplier, LPromptLeg, LCompLeg);
end;

function EstimateCostWithScope(const APricing: TModelPricing;
  APromptTokens, ACompletionTokens: Int64; ARateMultiplier: Int64;
  AScope: TRateScope): Int64; inline;
begin
  if AScope = rsTotal then
    Result := EstimateCostV2(APricing, APromptTokens, ACompletionTokens, ARateMultiplier)
  else
    Result := EstimateCost(APricing, APromptTokens, ACompletionTokens, ARateMultiplier);
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
