unit nextpas.core.billing.base;

{$I nextpas.core.settings.inc}

{** L3 billing 基础类型：通用计费域四件套 base 层，L3 独立 Owner=billing lane；纯数据类型，零依赖；四件套 base←intf←impl←facade 见 wallet/CONTRACT.md §0 与 billing 家族。 *}

interface

const
  BILLING_MIGRATION_VERSION = 1;
  BILLING_MAX_CODE_LEN = 64;
  BILLING_MAX_REASON_LEN = 128;

type
  TBillingAmount = record
    Cents: Int64;
    Currency: string;
  end;

  TBillingQuote = record
    Amount: TBillingAmount;
    Valid: Boolean;
  end;

  TBillingStatus = (bsPending, bsPaid, bsRefunded, bsFailed);

implementation

end.
