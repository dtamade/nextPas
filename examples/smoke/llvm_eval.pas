program Llvm_eval;

function EvalOp(A, Op, B: Integer): Integer;
begin
  if Op = 1 then
    EvalOp := A + B
  else if Op = 2 then
    EvalOp := A - B
  else if Op = 3 then
    EvalOp := A * B
  else if Op = 4 then
  begin
    if B <> 0 then
      EvalOp := A div B
    else
      EvalOp := 0;
  end
  else
    EvalOp := 0;
end;

function EvalChain(A, Op1, B, Op2, C: Integer): Integer;
var
  Temp: Integer;
begin
  Temp := EvalOp(A, Op1, B);
  EvalChain := EvalOp(Temp, Op2, C);
end;

begin
  Halt(EvalChain(2, 1, 5, 3, 6));
end.
