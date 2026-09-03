unit nextpas.core.billing;

{$I nextpas.core.settings.inc}

{** L3 billing 独立门面：通用计费域四件套纯聚合 Owner=billing lane，四件套 billing.base←billing.intf←billing.impl←billing 已独立；L3 业务独立仅 L0-L2 单向（bytes.ops/text.utils/text.conv 单源 inline/零拷贝），与 wallet 同级 L3 无同层耦合；兼容层 billing.wallet 已物理删除 2026-09-02，文件已移除，统一使用 nextpas.core.wallet，缺能力先反哺 owner。 *}

interface

uses
  nextpas.core.billing.base,
  nextpas.core.billing.intf,
  nextpas.core.billing.impl;

type
  TBillingAmount = nextpas.core.billing.base.TBillingAmount;
  TBillingQuote = nextpas.core.billing.base.TBillingQuote;
  TBillingStatus = nextpas.core.billing.base.TBillingStatus;
  IBillingCalculator = nextpas.core.billing.intf.IBillingCalculator;

function BillingNormalizeCode(const ACode: string): string; inline;
function BillingIsValidCode(const ACode: string): Boolean; inline;
function BillingCodeToBytes(const ACode: string): TBytes; inline;
function BillingFormatCents(ACents: Int64): string; inline;
function BillingCalculate(const AAmount: TBillingAmount; ARatePermyriad: Integer): TBillingAmount; inline;

implementation

uses
  nextpas.core.bytes.ops;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: billing facade must reuse bytes.ops'}
{$IFEND}

function BillingNormalizeCode(const ACode: string): string; inline;
begin
  Result := nextpas.core.billing.impl.BillingNormalizeCode(ACode);
end;

function BillingIsValidCode(const ACode: string): Boolean; inline;
begin
  Result := nextpas.core.billing.impl.BillingIsValidCode(ACode);
end;

function BillingCodeToBytes(const ACode: string): TBytes; inline;
begin
  Result := nextpas.core.billing.impl.BillingCodeToBytes(ACode);
end;

function BillingFormatCents(ACents: Int64): string; inline;
begin
  Result := nextpas.core.billing.impl.BillingFormatCents(ACents);
end;

function BillingCalculate(const AAmount: TBillingAmount; ARatePermyriad: Integer): TBillingAmount; inline;
begin
  Result := nextpas.core.billing.impl.BillingCalculate(AAmount, ARatePermyriad);
end;

end.
