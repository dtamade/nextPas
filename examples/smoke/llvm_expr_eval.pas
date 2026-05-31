program llvm_expr_eval;
type
  TExpr = class
    constructor Create;
    function Eval: Integer; virtual;
  end;
  TNum = class(TExpr)
    FVal: Integer;
    constructor Create(V: Integer);
    function Eval: Integer; override;
  end;
  TBinOp = class(TExpr)
    FLeft: TExpr;
    FRight: TExpr;
    FOp: Integer;
    constructor Create(L, R: TExpr; Op: Integer);
    function Eval: Integer; override;
  end;

constructor TExpr.Create; begin end;
function TExpr.Eval: Integer; begin Result := 0; end;
constructor TNum.Create(V: Integer); begin FVal := V; end;
function TNum.Eval: Integer; begin Result := FVal; end;
constructor TBinOp.Create(L, R: TExpr; Op: Integer);
begin FLeft := L; FRight := R; FOp := Op; end;
function TBinOp.Eval: Integer;
var LV, RV: Integer;
begin
  LV := FLeft.Eval;
  RV := FRight.Eval;
  if FOp = 0 then Result := LV + RV
  else if FOp = 1 then Result := LV - RV
  else Result := LV * RV;
end;

var E: TExpr;
begin
  E := TBinOp.Create(
    TBinOp.Create(TNum.Create(3), TNum.Create(4), 0),
    TNum.Create(2),
    2
  );
  Halt(E.Eval);
end.
