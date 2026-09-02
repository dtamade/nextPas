program test_quota;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.agent.quota,
  nextpas.core.agent,
  nextpas.core.test;

{ Phase1 T1.2 纯标量滚动窗口 — 5 cases：三窗口滚动+序列化（经门面与直引双路径），
  零IO O(1) 纯函数，HEAPTRC 0 unfreed。
  复刻 token888 contracts:682 逻辑，无 TConcurrentHashMap。 }

procedure TestDayWindow;
var
  S: Int64;
begin
  CheckEqual(Int64(86400), PlatformQuotaWindowSeconds(pqDay), 'day seconds 86400');
  CheckEqual(Int64(86400), nextpas.core.agent.PlatformQuotaWindowSeconds(pqDay), 'facade day 86400');
  Check(not PlatformQuotaExpired(pqDay, 0, 1000000), 'start 0 never expired');
  Check(not PlatformQuotaWindowExpired(pqDay, 1000, 1000 + 86400 - 1), 'not expired before boundary');
  Check(PlatformQuotaExpired(pqDay, 1000, 1000 + 86400), 'expired at boundary');
  Check(PlatformQuotaWindowExpired(pqDay, 1000, 1000 + 86400 + 1), 'expired after boundary');
  CheckEqual(Int64(500), PlatformQuotaUsage(pqDay, 500, 1000, 1000 + 100), 'usage before expiry');
  CheckEqual(Int64(0), PlatformQuotaUsage(pqDay, 500, 1000, 1000 + 86400), 'usage reset after expiry');
  CheckEqual(Int64(0), nextpas.core.agent.PlatformQuotaUsage(pqDay, 500, 1000, 1000 + 86400), 'facade usage reset');
end;

procedure TestWeekWindow;
begin
  CheckEqual(Int64(604800), PlatformQuotaWindowSeconds(pqWeek), 'week seconds 604800');
  CheckEqual(Int64(604800), nextpas.core.agent.PlatformQuotaWindowSeconds(pqWeek), 'facade week 604800');
  Check(not PlatformQuotaExpired(pqWeek, 2000, 2000 + 604800 - 1), 'week not expired');
  Check(PlatformQuotaExpired(pqWeek, 2000, 2000 + 604800), 'week expired at boundary');
  CheckEqual(Int64(1234), PlatformQuotaUsage(pqWeek, 1234, 2000, 2000 + 1000), 'week usage keep');
  CheckEqual(Int64(0), PlatformQuotaUsage(pqWeek, 1234, 2000, 2000 + 604800), 'week usage reset');
  Check(not PlatformQuotaWindowExpired(pqWeek, 0, 9999999), 'week start 0 never expired');
end;

procedure TestMonthWindow;
begin
  CheckEqual(Int64(2592000), PlatformQuotaWindowSeconds(pqMonth), 'month seconds 2592000');
  CheckEqual(Int64(2592000), nextpas.core.agent.PlatformQuotaWindowSeconds(pqMonth), 'facade month 2592000');
  Check(not PlatformQuotaExpired(pqMonth, 3000, 3000 + 2592000 - 1), 'month not expired');
  Check(PlatformQuotaExpired(pqMonth, 3000, 3000 + 2592000), 'month expired at boundary');
  CheckEqual(Int64(999), PlatformQuotaUsage(pqMonth, 999, 3000, 3000 + 100), 'month usage keep');
  CheckEqual(Int64(0), PlatformQuotaUsage(pqMonth, 999, 3000, 3000 + 2592000 + 5), 'month usage reset after');
end;

procedure TestExceeded;
begin
  { limit -1 不限 }
  Check(not PlatformQuotaExceeded(pqDay, -1, 999999, 1000, 1001, 1), 'limit -1 unlimited daily');
  Check(not PlatformQuotaExceeded(pqWeek, -1, 999999, 1000, 1001, 999999), 'limit -1 unlimited weekly');
  Check(not nextpas.core.agent.PlatformQuotaExceeded(pqDay, -1, 999999, 1000, 1001, 1), 'facade unlimited');
  { limit 0 禁用 }
  Check(PlatformQuotaExceeded(pqDay, 0, 0, 0, 1000, 0), 'limit 0 disabled even zero usage');
  Check(PlatformQuotaExceeded(pqMonth, 0, 0, 1000, 1001, 0), 'limit 0 disabled month');
  { limit >0 正常阈值 }
  Check(not PlatformQuotaExceeded(pqDay, 1000, 400, 1000, 1001, 500), '400+500<=1000 not exceeded');
  Check(PlatformQuotaExceeded(pqDay, 1000, 400, 1000, 1001, 601), '400+601>1000 exceeded');
  { 过期重置后以 0 计量 }
  Check(not PlatformQuotaExceeded(pqDay, 1000, 900, 1000, 1000 + 86400, 100), 'expired resets to 0 then 100<=1000');
  Check(PlatformQuotaExceeded(pqDay, 100, 900, 1000, 1000 + 86400, 101), 'expired 0+101>100 exceeded');
  { 周窗口过期场景 }
  Check(not PlatformQuotaExceeded(pqWeek, 5000, 5000, 2000, 2000 + 604800, 0), 'week expired 0+0 not exceeded');
end;

procedure TestSerialize;
var
  Item: TPlatformQuotaItem;
  S, F: string;
  Doc: IJsonDocument;
  V: TJsonValue;
begin
  Item := Default(TPlatformQuotaItem);
  Item.Protocol := 'openai';
  Item.DailyLimitUsd6 := -1;
  Item.WeeklyLimitUsd6 := 5000;
  Item.MonthlyLimitUsd6 := -1;
  Item.DailyUsageUsd6 := 123;
  Item.WeeklyUsageUsd6 := 4000;
  Item.MonthlyUsageUsd6 := 777;
  Item.DailyWindowStart := 1000;
  Item.WeeklyWindowStart := 0;
  Item.MonthlyWindowStart := 2000;
  S := SerializePlatformQuotaItem(Item, 1000 + 100);
  Check(S <> '', 'serialize non-empty');
  Check(nextpas.core.agent.SerializePlatformQuotaItem(Item, 1000 + 100) = S, 'facade serialize equal');
  Check(PlatformQuotaSerialize(Item, 1000 + 100) = S, 'alias serialize equal');
  Doc := JsonParse(S);
  Check(not Doc.HasError, 'serialize valid json');
  Check(Doc.Root.IsObject, 'root is object');
  V := Doc.Root.Get('protocol');
  Check(V.IsStr and (V.AsStr.ToString = 'openai'), 'protocol field');
  V := Doc.Root.Get('daily_limit_usd6');
  Check(V.IsNull, 'daily limit -1 => null');
  V := Doc.Root.Get('weekly_limit_usd6');
  Check(V.IsInt and (V.AsInt = 5000), 'weekly limit 5000');
  V := Doc.Root.Get('monthly_limit_usd6');
  Check(V.IsNull, 'monthly limit -1 => null');
  V := Doc.Root.Get('daily_usage_usd6');
  Check(V.IsInt and (V.AsInt = 123), 'daily usage effective 123');
  V := Doc.Root.Get('weekly_usage_usd6');
  Check(V.IsInt and (V.AsInt = 4000), 'weekly usage 4000');
  { weekly reset_at must be omitted because start=0 }
  Check(not Doc.Root.ObjectHas('weekly_reset_at'), 'weekly_reset_at omitted when start 0');
  V := Doc.Root.Get('daily_reset_at');
  Check(V.IsInt and (V.AsInt = 1000 + 86400), 'daily_reset_at start+86400');
  V := Doc.Root.Get('monthly_reset_at');
  Check(V.IsInt and (V.AsInt = 2000 + 2592000), 'monthly_reset_at start+2592000');
  { expiry resets usage to 0 plus reset_at still present }
  Item.DailyUsageUsd6 := 999;
  Item.DailyWindowStart := 1000;
  S := SerializePlatformQuotaItem(Item, 1000 + 86400);
  Doc := JsonParse(S);
  V := Doc.Root.Get('daily_usage_usd6');
  Check(V.IsInt and (V.AsInt = 0), 'daily usage reset to 0 after expiry in serialize');
  { all limits -1 => all null }
  Item := Default(TPlatformQuotaItem);
  Item.Protocol := 'claude';
  Item.DailyLimitUsd6 := -1;
  Item.WeeklyLimitUsd6 := -1;
  Item.MonthlyLimitUsd6 := -1;
  Item.DailyWindowStart := 0;
  Item.WeeklyWindowStart := 0;
  Item.MonthlyWindowStart := 0;
  S := SerializePlatformQuotaItem(Item, 999999);
  Doc := JsonParse(S);
  V := Doc.Root.Get('daily_limit_usd6');
  Check(V.IsNull, 'all null - daily');
  V := Doc.Root.Get('weekly_limit_usd6');
  Check(V.IsNull, 'all null - weekly');
  V := Doc.Root.Get('monthly_limit_usd6');
  Check(V.IsNull, 'all null - monthly');
  Check(not Doc.Root.ObjectHas('daily_reset_at'), 'no reset_at when start 0');
  Check(not Doc.Root.ObjectHas('weekly_reset_at'), 'no weekly reset when 0');
  Check(not Doc.Root.ObjectHas('monthly_reset_at'), 'no monthly reset when 0');
  { ensure helper F used to silence warning }
  F := '';
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.quota');
  T.Test('day window rolling', @TestDayWindow);
  T.Test('week window rolling', @TestWeekWindow);
  T.Test('month window rolling', @TestMonthWindow);
  T.Test('exceeded logic', @TestExceeded);
  T.Test('serialize', @TestSerialize);
  if not T.Run then Halt(1);
end.
