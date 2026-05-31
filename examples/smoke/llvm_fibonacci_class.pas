program llvm_fibonacci_class;
type
  TFibCalc = class
    FMemo: array of Integer;
    FSize: Integer;
    constructor Create(N: Integer);
    function Fib(N: Integer): Integer; virtual;
  end;

constructor TFibCalc.Create(N: Integer);
begin
  FSize := N + 1;
  SetLength(FMemo, FSize);
  FMemo[0] := 0;
  FMemo[1] := 0;
end;

function TFibCalc.Fib(N: Integer): Integer;
begin
  if N <= 1 then
    Result := N * 2
  else
  begin
    if FMemo[N] = 0 then
      FMemo[N] := Fib(N - 1) + Fib(N - 2);
    Result := FMemo[N];
  end;
end;

var C: TFibCalc;
begin
  C := TFibCalc.Create(10);
  Halt(C.Fib(8));
end.
