program test_as2;
type
  TBase = class
    constructor Create;
    function GetId: Integer; virtual;
  end;
  TChild = class(TBase)
    FExtra: Integer;
    constructor Create(E: Integer);
    function GetId: Integer; override;
    function GetExtra: Integer; virtual;
  end;

constructor TBase.Create; begin end;
function TBase.GetId: Integer; begin Result := 1; end;
constructor TChild.Create(E: Integer); begin FExtra := E; end;
function TChild.GetId: Integer; begin Result := 2; end;
function TChild.GetExtra: Integer; begin Result := FExtra; end;

var
  B: TBase;
  C: TChild;
begin
  B := TChild.Create(42);
  WriteLn(B.GetId);
  C := B as TChild;
  Halt(C.GetExtra);
end.
