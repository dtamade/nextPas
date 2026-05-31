program llvm_mutual_recursion;
function IsEven(N: Integer): Integer; forward;
function IsOdd(N: Integer): Integer; forward;

function IsEven(N: Integer): Integer;
begin
  if N = 0 then Result := 1
  else Result := IsOdd(N - 1);
end;

function IsOdd(N: Integer): Integer;
begin
  if N = 0 then Result := 0
  else Result := IsEven(N - 1);
end;

begin
  Halt(IsEven(10) * 10 + IsOdd(7));
end.
