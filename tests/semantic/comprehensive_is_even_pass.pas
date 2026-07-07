{ objfpc}{+}
program comprehensive_is_even_pass;
function IsEven(N: Integer): Boolean;
begin IsEven:=N mod 2=0; end;
function IsOdd(N: Integer): Boolean;
begin IsOdd:=N mod 2<>0; end;
begin
  if not IsEven(2) then Halt(1);
  if IsEven(3) then Halt(2);
  if not IsOdd(3) then Halt(3);
  if IsOdd(4) then Halt(4);
end.
