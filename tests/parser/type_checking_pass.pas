program Type_checking_pass;

{$mode objfpc}{$H+}

type
  TBase = class
  public
    function GetValue: Integer; virtual;
  end;

  TDerived = class(TBase)
  private
    FExtra: Integer;
  public
    constructor Create(AExtra: Integer);
    function GetValue: Integer; override;
  end;

function TBase.GetValue: Integer;
begin
  Result := 0;
end;

constructor TDerived.Create(AExtra: Integer);
begin
  FExtra := AExtra;
end;

function TDerived.GetValue: Integer;
begin
  Result := FExtra;
end;

var
  Obj: TBase;
  D: TDerived;
  I: Integer;
begin
  Obj := TDerived.Create(42);

  if Obj is TDerived then
  begin
    D := Obj as TDerived;
    I := D.GetValue;
  end;

  Obj.Free;
end.
