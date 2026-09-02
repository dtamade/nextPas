{**
 * nextpas.core.agent.quota - 平台配额标量滚动窗口（纯函数，零IO）。
 *
 * 契约权威：~/projects/token888/src/tk888/contracts/tk888.contracts.pas:682
 * 平台窗口语义（K58）：用户×协议 日/周/月用量窗口（μUSD 整数，标量滚动
 * —— usage + window_start 起点，过期重置）。不建行=不限；limit -1=不限
 * （JSON null）；0=禁用；>0=上限。纯标量 O(1) 可单测，无 map/无IO。
 * 本单元零 IO，只提供纯函数；并发/落库由上层负责（与 token888
 * TConcurrentHashMap 解耦）。
 *}

unit nextpas.core.agent.quota;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformQuotaWindowKind = (pqDay, pqWeek, pqMonth);

  TPlatformQuotaItem = record
    Protocol: string;
    DailyLimitUsd6: Int64;
    WeeklyLimitUsd6: Int64;
    MonthlyLimitUsd6: Int64;
    DailyUsageUsd6: Int64;
    WeeklyUsageUsd6: Int64;
    MonthlyUsageUsd6: Int64;
    DailyWindowStart: Int64;
    WeeklyWindowStart: Int64;
    MonthlyWindowStart: Int64;
  end;
  TPlatformQuotaArray = array of TPlatformQuotaItem;

function PlatformQuotaWindowSeconds(const AKind: TPlatformQuotaWindowKind): Int64; inline;

function PlatformQuotaWindowExpired(const AKind: TPlatformQuotaWindowKind;
  const AStart, ANowSec: Int64): Boolean; inline;
function PlatformQuotaExpired(const AKind: TPlatformQuotaWindowKind;
  const AStart, ANowSec: Int64): Boolean; inline;

function PlatformQuotaUsage(const AKind: TPlatformQuotaWindowKind;
  const AUsage, AStart, ANowSec: Int64): Int64; inline;

function PlatformQuotaExceeded(const AKind: TPlatformQuotaWindowKind;
  const ALimit, AUsage, AStart, ANowSec, AEstCost: Int64): Boolean; inline;

function SerializePlatformQuotaItem(const AItem: TPlatformQuotaItem;
  const ANowSec: Int64): string;
function PlatformQuotaSerialize(const AItem: TPlatformQuotaItem;
  const ANowSec: Int64): string; inline;

implementation

uses
  nextpas.core.json.builder;

function PlatformQuotaWindowSeconds(const AKind: TPlatformQuotaWindowKind): Int64;
begin
  case AKind of
    pqDay: Result := 86400;
    pqWeek: Result := 604800;
  else
    Result := 2592000;
  end;
end;

function PlatformQuotaWindowExpired(const AKind: TPlatformQuotaWindowKind;
  const AStart, ANowSec: Int64): Boolean;
begin
  Result := (AStart > 0) and (ANowSec - AStart >= PlatformQuotaWindowSeconds(AKind));
end;

function PlatformQuotaExpired(const AKind: TPlatformQuotaWindowKind;
  const AStart, ANowSec: Int64): Boolean;
begin
  Result := PlatformQuotaWindowExpired(AKind, AStart, ANowSec);
end;

function PlatformQuotaUsage(const AKind: TPlatformQuotaWindowKind;
  const AUsage, AStart, ANowSec: Int64): Int64;
begin
  if PlatformQuotaWindowExpired(AKind, AStart, ANowSec) then
    Result := 0
  else
    Result := AUsage;
end;

function PlatformQuotaExceeded(const AKind: TPlatformQuotaWindowKind;
  const ALimit, AUsage, AStart, ANowSec, AEstCost: Int64): Boolean;
begin
  if ALimit < 0 then
    Result := False
  else if ALimit = 0 then
    Result := True
  else
    Result := PlatformQuotaUsage(AKind, AUsage, AStart, ANowSec) + AEstCost > ALimit;
end;

function SerializePlatformQuotaItem(const AItem: TPlatformQuotaItem;
  const ANowSec: Int64): string;
var
  LB: IJsonBuilder;
begin
  LB := JsonBuilder;
  LB.BeginObject;
  LB.Key('protocol');
  LB.Str(AItem.Protocol);
  if AItem.DailyLimitUsd6 < 0 then
  begin
    LB.Key('daily_limit_usd6');
    LB.Null;
  end
  else
  begin
    LB.Key('daily_limit_usd6');
    LB.Int(AItem.DailyLimitUsd6);
  end;
  if AItem.WeeklyLimitUsd6 < 0 then
  begin
    LB.Key('weekly_limit_usd6');
    LB.Null;
  end
  else
  begin
    LB.Key('weekly_limit_usd6');
    LB.Int(AItem.WeeklyLimitUsd6);
  end;
  if AItem.MonthlyLimitUsd6 < 0 then
  begin
    LB.Key('monthly_limit_usd6');
    LB.Null;
  end
  else
  begin
    LB.Key('monthly_limit_usd6');
    LB.Int(AItem.MonthlyLimitUsd6);
  end;
  LB.Key('daily_usage_usd6');
  LB.Int(PlatformQuotaUsage(pqDay, AItem.DailyUsageUsd6, AItem.DailyWindowStart, ANowSec));
  LB.Key('weekly_usage_usd6');
  LB.Int(PlatformQuotaUsage(pqWeek, AItem.WeeklyUsageUsd6, AItem.WeeklyWindowStart, ANowSec));
  LB.Key('monthly_usage_usd6');
  LB.Int(PlatformQuotaUsage(pqMonth, AItem.MonthlyUsageUsd6, AItem.MonthlyWindowStart, ANowSec));
  if AItem.DailyWindowStart > 0 then
  begin
    LB.Key('daily_reset_at');
    LB.Int(AItem.DailyWindowStart + PlatformQuotaWindowSeconds(pqDay));
  end;
  if AItem.WeeklyWindowStart > 0 then
  begin
    LB.Key('weekly_reset_at');
    LB.Int(AItem.WeeklyWindowStart + PlatformQuotaWindowSeconds(pqWeek));
  end;
  if AItem.MonthlyWindowStart > 0 then
  begin
    LB.Key('monthly_reset_at');
    LB.Int(AItem.MonthlyWindowStart + PlatformQuotaWindowSeconds(pqMonth));
  end;
  LB.EndObject;
  Result := LB.ToString;
end;

function PlatformQuotaSerialize(const AItem: TPlatformQuotaItem;
  const ANowSec: Int64): string;
begin
  Result := SerializePlatformQuotaItem(AItem, ANowSec);
end;

end.
