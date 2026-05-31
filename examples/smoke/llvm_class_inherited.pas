program Llvm_class_inherited;
type
  TBase = class
    FValue: Integer;
    constructor Create(AVal: Integer);
    function GetValue: Integer; virtual;
  end;
  TDerived = class(TBase)
    FBonus: Integer;
    constructor Create(AVal, ABonus: Integer);
    function GetValue: Integer; override;
  end;

constructor TBase.Create(AVal: Integer);
begin
  FValue := AVal;
end;

function TBase.GetValue: Integer;
begin
  GetValue := FValue;
end;

constructor TDerived.Create(AVal, ABonus: Integer);
begin
  inherited Create(AVal);
  FBonus := ABonus;
end;

function TDerived.GetValue: Integer;
begin
  GetValue := FValue + FBonus;
end;

var
  D: TDerived;
begin
  D := TDerived.Create(30, 12);
  Halt(D.GetValue);
end.
