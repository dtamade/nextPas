program test_pricing;

{$I nextpas.core.settings.inc}

{ Phase1 T1.1 纯策略门：EstimateCost 整数μUSD 四舍五入 + ImageTier max-edge 分档
  同源 tk888.billing:22,212 / billing:470，零堆分配，HEAPTRC OK
  5 cases：边界舍入 + 费率 + 分档（含 2048x2048→2000 特判）
  C2（2026-09-05）：V1 记录口径冻结（倍率仅 completion 腿）标 deprecated；
  V2 整单总额口径（EstimateCostV2/EstimateCostWithScope+rsTotal）与
  token888 tests/tk888_billing TestEstimateCost 跨仓金色向量对拍：
  0.5x/1x/2x × prompt-only/completion-only/混合 × 边界 499/500，
  总额与分腿明细双断言 }

uses
  nextpas.core.agent.base,
  nextpas.core.agent.pricing,
  nextpas.core.agent,
  nextpas.core.test;

procedure TestEstimateCostZeroAndBasic;
var
  LPricing: TModelPricing;
begin
  LPricing.Per1kPromptUsd := 2000;
  LPricing.Per1kCompletionUsd := 4000;
  LPricing.RateDenominator := 10000;
  CheckEqual(Int64(0),
    EstimateCost(LPricing, 0, 0), 'zero tokens zero cost');
  CheckEqual(Int64(0),
    nextpas.core.agent.EstimateCost(LPricing, 0, 0), 'facade zero');
  { 1 prompt token *2000 per1k → (2000+500)div1000=2 }
  CheckEqual(Int64(2),
    EstimateCost(LPricing, 1, 0), '1 prompt token');
  { 1000 prompt tokens → 2000 }
  CheckEqual(Int64(2000),
    EstimateCost(LPricing, 1000, 0), '1000 prompt tokens');
end;

procedure TestEstimateCostRounding;
var
  LPricing: TModelPricing;
begin
  { per1k=500 临界：1*500+500=1000 div1000=1 恰好进位 }
  LPricing.Per1kPromptUsd := 500;
  LPricing.Per1kCompletionUsd := 500;
  LPricing.RateDenominator := 10000;
  CheckEqual(Int64(1),
    EstimateCost(LPricing, 1, 0, 10000), 'rounding up at 500');
  { per1k=499：499+500=999 div1000=0 舍去 }
  LPricing.Per1kPromptUsd := 499;
  CheckEqual(Int64(0),
    EstimateCost(LPricing, 1, 0, 10000), 'rounding down at 499');
  { completion 侧含 rate 舍入：1*1*1 +5000 /10000 → 0 / 1 边界 }
  LPricing.Per1kCompletionUsd := 1;
  CheckEqual(Int64(0),
    EstimateCost(LPricing, 0, 1, 1), 'completion rate tiny rounds to 0');
  CheckEqual(Int64(1),
    EstimateCost(LPricing, 0, 1, 10000), 'completion 1 token 1*1*10000+5000 div10000=1');
  { 更精确：5000 completion *1 *10000 =50M +5000 /10000=5000 }
  CheckEqual(Int64(5000),
    EstimateCost(LPricing, 0, 5000, 10000), 'completion 5000 tokens');
end;

procedure TestEstimateCostRate;
var
  LPricing: TModelPricing;
  LBase, LDouble: Int64;
begin
  LPricing.Per1kPromptUsd := 2000;
  LPricing.Per1kCompletionUsd := 4000;
  LPricing.RateDenominator := 10000;
  { base 1.0x：prompt 1000 + completion 500 }
  LBase := EstimateCost(LPricing, 1000, 500, 10000);
  { prompt 1000*2000=2M+500 /1000=2000; completion 500*4000*10000=20B+5000/10000=2M → total 2_002_000 }
  CheckEqual(Int64(2002000), LBase, 'base 1.0x');
  { 2.0x：completion 翻倍，prompt 按 spec 不跟倍（completion*rate 路径） }
  LDouble := EstimateCost(LPricing, 1000, 500, 20000);
  CheckEqual(Int64(4002000), LDouble, '2.0x completion doubled');
  { <=0 按 1.0x 收敛（billing ApplyRate 防御） }
  CheckEqual(LBase, EstimateCost(LPricing, 1000, 500, 0), 'rate 0 fallback 1.0x');
  CheckEqual(LBase, EstimateCost(LPricing, 1000, 500, -5), 'rate negative fallback');
end;

procedure TestEstimateCostV2TotalScope;
var
  LPricing: TModelPricing;
  LPromptLeg, LCompLeg, LTotal: Int64;
begin
  { 跨仓金色向量（token888 tests/tk888_billing TestEstimateCost 对拍）：
    gpt-4o 口径 prompt 2500 / completion 10000 per1k；
    混合 1000 prompt + 500 completion 基费 2500 + 5000 = 7500，
    0.5x → 3750，1x → 7500 恒等，2x → 15000 }
  LPricing.Per1kPromptUsd := 2500;
  LPricing.Per1kCompletionUsd := 10000;
  LPricing.RateDenominator := 10000;
  LTotal := EstimateCostLegsV2(LPricing, 1000, 500, 5000, LPromptLeg, LCompLeg);
  CheckEqual(Int64(2500), LPromptLeg, 'v2 mixed prompt leg');
  CheckEqual(Int64(5000), LCompLeg, 'v2 mixed completion leg');
  CheckEqual(Int64(3750), LTotal, 'v2 mixed 0.5x total');
  CheckEqual(Int64(3750), EstimateCostV2(LPricing, 1000, 500, 5000), 'v2 mixed 0.5x');
  CheckEqual(Int64(7500), EstimateCostV2(LPricing, 1000, 500, 10000), 'v2 mixed 1x identity');
  CheckEqual(Int64(7500), nextpas.core.agent.EstimateCostV2(LPricing, 1000, 500, 10000), 'facade v2 1x');
  CheckEqual(Int64(15000), EstimateCostV2(LPricing, 1000, 500, 20000), 'v2 mixed 2x');
  { prompt-only：V1 冻结语义下 prompt 腿不跟倍（恒 2500），V2 整单作用 }
  LTotal := EstimateCostLegsV2(LPricing, 1000, 0, 5000, LPromptLeg, LCompLeg);
  CheckEqual(Int64(2500), LPromptLeg, 'v2 prompt-only leg');
  CheckEqual(Int64(0), LCompLeg, 'v2 prompt-only completion leg zero');
  CheckEqual(Int64(1250), LTotal, 'v2 prompt-only 0.5x');
  CheckEqual(Int64(2500), EstimateCostV2(LPricing, 1000, 0, 10000), 'v2 prompt-only 1x');
  CheckEqual(Int64(5000), EstimateCostV2(LPricing, 1000, 0, 20000), 'v2 prompt-only 2x');
  CheckEqual(Int64(2500), EstimateCost(LPricing, 1000, 0, 5000), 'v1 prompt-only frozen ignores rate');
  { completion-only：V1/V2 同值（completion 腿是 V1 唯一作用域） }
  LTotal := EstimateCostLegsV2(LPricing, 0, 500, 5000, LPromptLeg, LCompLeg);
  CheckEqual(Int64(0), LPromptLeg, 'v2 completion-only prompt leg zero');
  CheckEqual(Int64(5000), LCompLeg, 'v2 completion-only leg');
  CheckEqual(Int64(2500), LTotal, 'v2 completion-only 0.5x');
  CheckEqual(Int64(5000), EstimateCostV2(LPricing, 0, 500, 10000), 'v2 completion-only 1x');
  CheckEqual(Int64(10000), EstimateCostV2(LPricing, 0, 500, 20000), 'v2 completion-only 2x');
  { 边界 499/500：per1k=500 时 1 token 进位为 1，0.5x 总额仍为 1，2x 为 2；
    per1k=499 时基费为 0，任何倍率仍为 0 }
  LPricing.Per1kPromptUsd := 500;
  LPricing.Per1kCompletionUsd := 500;
  CheckEqual(Int64(1), EstimateCostV2(LPricing, 1, 0, 5000), 'v2 boundary 500 0.5x');
  CheckEqual(Int64(1), EstimateCostV2(LPricing, 1, 0, 10000), 'v2 boundary 500 1x');
  CheckEqual(Int64(2), EstimateCostV2(LPricing, 1, 0, 20000), 'v2 boundary 500 2x');
  LPricing.Per1kPromptUsd := 499;
  CheckEqual(Int64(0), EstimateCostV2(LPricing, 1, 0, 5000), 'v2 boundary 499 0.5x stays 0');
  CheckEqual(Int64(0), EstimateCostV2(LPricing, 1, 0, 20000), 'v2 boundary 499 2x stays 0');
  { <=0 按 1.0x 收敛；负 tokens 钳 0 }
  LPricing.Per1kPromptUsd := 2500;
  LPricing.Per1kCompletionUsd := 10000;
  CheckEqual(Int64(7500), EstimateCostV2(LPricing, 1000, 500, 0), 'v2 rate 0 fallback 1.0x');
  CheckEqual(Int64(7500), EstimateCostV2(LPricing, 1000, 500, -5), 'v2 rate negative fallback');
  CheckEqual(Int64(0), EstimateCostV2(LPricing, -5, -10, 20000), 'v2 negative clamped');
end;

procedure TestEstimateCostV2RateDenominator;
var
  LPricing: TModelPricing;
begin
  LPricing.Per1kPromptUsd := 2500;
  LPricing.Per1kCompletionUsd := 10000;
  { RateDenominator 自 V2 起生效：分母 20000 下 rate=10000 即 0.5x }
  LPricing.RateDenominator := 20000;
  CheckEqual(Int64(3750), EstimateCostV2(LPricing, 1000, 500, 10000), 'v2 custom denominator halves');
  CheckEqual(Int64(7500), EstimateCostV2(LPricing, 1000, 500, 20000), 'v2 custom denominator 1x');
  { 非法分母回落 10000 }
  LPricing.RateDenominator := 0;
  CheckEqual(Int64(3750), EstimateCostV2(LPricing, 1000, 500, 5000), 'v2 zero denominator fallback');
  LPricing.RateDenominator := -3;
  CheckEqual(Int64(15000), EstimateCostV2(LPricing, 1000, 500, 20000), 'v2 negative denominator fallback');
end;

procedure TestEstimateCostWithScope;
var
  LPricing: TModelPricing;
begin
  LPricing.Per1kPromptUsd := 2000;
  LPricing.Per1kCompletionUsd := 4000;
  LPricing.RateDenominator := 10000;
  { 双读：completion-only 作用域恒等于冻结 V1；total 恒等于 V2 }
  CheckEqual(EstimateCost(LPricing, 1000, 500, 20000),
    EstimateCostWithScope(LPricing, 1000, 500, 20000, rsCompletionOnly), 'scope completion-only matches v1');
  CheckEqual(EstimateCostV2(LPricing, 1000, 500, 5000),
    EstimateCostWithScope(LPricing, 1000, 500, 5000, rsTotal), 'scope total matches v2');
  { 整单：基费 2000 + 2000 = 4000；0.5x → 2000，1x → 4000 }
  CheckEqual(Int64(2000), EstimateCostWithScope(LPricing, 1000, 500, 5000, rsTotal), 'scope total 0.5x');
  CheckEqual(Int64(4000), EstimateCostWithScope(LPricing, 1000, 500, 10000, rsTotal), 'scope total 1x');
end;

procedure TestApplyRateTotal;
begin
  CheckEqual(Int64(3750), ApplyRateTotal(7500, 5000, 10000), 'apply 0.5x');
  CheckEqual(Int64(15000), ApplyRateTotal(7500, 20000, 10000), 'apply 2x');
  CheckEqual(Int64(7500), ApplyRateTotal(7500, 10000, 10000), 'apply 1x identity');
  CheckEqual(Int64(2), ApplyRateTotal(3, 5000, 10000), 'apply rounding up');
  CheckEqual(Int64(7500), ApplyRateTotal(7500, 0, 10000), 'apply unset rate identity');
  CheckEqual(Int64(3750), ApplyRateTotal(7500, 5000, 0), 'apply unset denominator falls back 10000');
end;

procedure TestImageTierBoundaries;
begin
  CheckEqual(Int64(1000), ImageTierOf(512, 512), '512x512 ->1k');
  CheckEqual(Int64(1000), ImageTierOf(1024, 1024), '1024x1024 ->1k boundary');
  CheckEqual(Int64(1000), nextpas.core.agent.ImageTierOf(1024, 1024), 'facade 1024');
  CheckEqual(Int64(2000), ImageTierOf(1025, 800), '1025 ->2k just over');
  CheckEqual(Int64(2000), ImageTierOf(1024, 2048), '1024x2048 ->2k');
  CheckEqual(Int64(2000), ImageTierOf(2048, 2048), '2048x2048 special ->2k');
  CheckEqual(Int64(2000), ImageTierOf(2048, 1152), '2048x1152 ->2k');
end;

procedure TestImageTierLarge;
begin
  CheckEqual(Int64(4000), ImageTierOf(2049, 1024), '2049 ->4k');
  CheckEqual(Int64(4000), ImageTierOf(3840, 2160), '3840x2160 ->4k');
  CheckEqual(Int64(4000), ImageTierOf(4000, 4000), '4000x4000 ->4k');
  CheckEqual(Int64(1000), ImageTierOf(0, 0), '0x0 fallback 1k');
  CheckEqual(Int64(1000), ImageTierOf(1, 1024), '1x1024 ->1k');
end;

procedure TestEstimateCostNegativeClamp;
var
  LPricing: TModelPricing;
  LU: TTokenUsage;
begin
  LPricing.Per1kPromptUsd := 2000;
  LPricing.Per1kCompletionUsd := 4000;
  LPricing.RateDenominator := 10000;
  CheckEqual(Int64(0), EstimateCost(LPricing, -5, -10), 'negative prompt/completion clamped to 0');
  CheckEqual(Int64(0), EstimateCost(-5, -10), 'pricing scalar negative clamped');
  CheckEqual(Int64(40), EstimateCost(-5, 10, 2000, 4000), 'one side negative per-side clamped (prompt 0 + 10*4000/1000=40)');
  LU := Default(TTokenUsage);
  LU.InputTokens := -5;
  LU.OutputTokens := -10;
  LU.CacheReadInputTokens := -1;
  LU.CacheWriteInputTokens := -1;
  LU.ReasoningTokens := -1;
  CheckEqual(Int64(0), EstimateCost(LU), 'usage negative ->0');
  LU.InputTokens := 100;
  LU.OutputTokens := -5;
  Check(EstimateCost(LU) > 0, 'partial negative still positive cost');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.pricing');
  T.Test('estimate cost zero and basic', @TestEstimateCostZeroAndBasic);
  T.Test('estimate cost rounding', @TestEstimateCostRounding);
  T.Test('estimate cost rate', @TestEstimateCostRate);
  T.Test('estimate cost v2 total scope', @TestEstimateCostV2TotalScope);
  T.Test('estimate cost v2 rate denominator', @TestEstimateCostV2RateDenominator);
  T.Test('estimate cost with scope', @TestEstimateCostWithScope);
  T.Test('apply rate total', @TestApplyRateTotal);
  T.Test('image tier boundaries', @TestImageTierBoundaries);
  T.Test('image tier large', @TestImageTierLarge);
  T.Test('estimate cost negative clamp', @TestEstimateCostNegativeClamp);
  if not T.Run then
    Halt(1);
end.
