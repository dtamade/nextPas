unit nextpas.core.billing.intf;

{$I nextpas.core.settings.inc}

{** L3 billing 接口抽象：通用计费域四件套 intf 层，隔离定价/支付能力；base←intf 单向，L3 独立 Owner=billing lane；缺能力先反哺 owner。 *}

interface

uses
  nextpas.core.billing.base;

type
  IBillingCalculator = interface
    ['{B1B2C3D4-3333-4B2E-9F00-BBCCDD001122}']
    function Calculate(const AAmount: TBillingAmount; ARatePermyriad: Integer): TBillingAmount;
    function IsValidAmount(const AAmount: TBillingAmount): Boolean;
  end;

implementation

end.
