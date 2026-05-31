program test_is_check;
type
  TBase = class
    constructor Create;
    function GetId: Integer; virtual;
  end;
  TChild = class(TBase)
    constructor Create;
    function GetId: Integer; override;
  end;

constructor TBase.Create; begin end;
function TBase.GetId: Integer; begin Result := 1; end;
constructor TChild.Create; begin end;
function TChild.GetId: Integer; begin Result := 2; end;

var
  B: TBase;
  C: TChild;
  R: Integer;
begin
  C := TChild.Create;
  B := TBase.Create;
  R := 0;
  if C is TChild then
    R := R + 10;
  if C is TBase then
    R := R + 20;
  if B is TChild then
    R := R + 100;
  if B is TBase then
    R := R + 1;
  Halt(R);
end.
