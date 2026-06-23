{$mode objfpc}{$H+}
unit inherited_create_xunit_parent;

{ P2-2 cross-unit inheritance verification (Codex candidate A).

  Parent class TBase lives in THIS unit. A consumer program declares
  TDerived = class(TBase) WITHOUT its own Create and calls TDerived.Create(n).
  This exercises the inheritance-chain walk when the parent type is resolved
  via an imported unit — the scenario where ParentTypeId was suspected of
  being zeroed by the $size const guard during ProcessTypeSection. }

interface

type
  TBase = class
  private
    FValue: LongInt;
  public
    constructor Create(AValue: LongInt);
    function GetValue: LongInt;
  end;

implementation

constructor TBase.Create(AValue: LongInt);
begin
  FValue := AValue;
end;

function TBase.GetValue: LongInt;
begin
  Result := FValue;
end;

end.
