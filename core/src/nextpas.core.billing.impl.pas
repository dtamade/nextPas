unit nextpas.core.billing.impl;

{$I nextpas.core.settings.inc}

{** L3 billing 单源实现：通用计费域四件套 impl 层，Owner=billing lane；L3 业务独立仅 L0-L2 单向（bytes.ops/text.utils/text.conv 单源），物理 billing.impl 单源，门面 inline 零拷贝聚合；缺能力先反哺 owner。 *}

interface

uses
  nextpas.core.billing.base,
  nextpas.core.billing.intf;

function BillingNormalizeCode(const ACode: string): string; inline;
function BillingIsValidCode(const ACode: string): Boolean; inline;
function BillingCodeToBytes(const ACode: string): TBytes; inline;
function BillingFormatCents(ACents: Int64): string; inline;
function BillingCalculate(const AAmount: TBillingAmount; ARatePermyriad: Integer): TBillingAmount; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.text.utils,
  nextpas.core.text.conv;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: billing must reuse bytes.ops'}
{$IFEND}

function BillingNormalizeCode(const ACode: string): string; inline;
begin
  Result := Trim(ACode);
end;

function BillingIsValidCode(const ACode: string): Boolean; inline;
var
  L: string;
begin
  L := Trim(ACode);
  Result := (Length(L) > 0) and (Length(L) <= BILLING_MAX_CODE_LEN);
end;

function BillingCodeToBytes(const ACode: string): TBytes; inline;
begin
  Result := StringToBytes(Trim(ACode));
end;

function BillingFormatCents(ACents: Int64): string; inline;
begin
  Result := IntToStr(ACents);
end;

function BillingCalculate(const AAmount: TBillingAmount; ARatePermyriad: Integer): TBillingAmount; inline;
begin
  Result := AAmount;
  if ARatePermyriad <= 0 then Exit;
  if ARatePermyriad >= 10000 then Exit;
  Result.Cents := (AAmount.Cents * ARatePermyriad + 5000) div 10000;
end;

end.
