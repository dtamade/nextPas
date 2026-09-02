program test_pricing;

{$I nextpas.core.settings.inc}

{ Phase1 T1.1 纯策略门：EstimateCost 整数μUSD 四舍五入 + ImageTier max-edge 分档
  同源 tk888.billing:22,212 / billing:470，零堆分配，HEAPTRC OK
  5 cases：边界舍入 + 费率 + 分档（含 2048x2048→2000 特判） }

uses
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
  CheckEqual(Int64(0), EstimateCost(-5, 10, 2000, 4000), 'one side negative clamped');
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
  T.Test('image tier boundaries', @TestImageTierBoundaries);
  T.Test('image tier large', @TestImageTierLarge);
  T.Test('estimate cost negative clamp', @TestEstimateCostNegativeClamp);
  if not T.Run then
    Halt(1);
end.
