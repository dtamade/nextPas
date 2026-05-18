program Control_flow_pass;

{$mode objfpc}{$H+}

type
  TColor = (clRed, clGreen, clBlue, clYellow, clWhite, clBlack);

function ColorName(C: TColor): string;
begin
  case C of
    clRed: Result := 'Red';
    clGreen: Result := 'Green';
    clBlue: Result := 'Blue';
    clYellow: Result := 'Yellow';
    clWhite: Result := 'White';
    clBlack: Result := 'Black';
  else
    Result := 'Unknown';
  end;
end;

function Fibonacci(N: Integer): Integer;
var
  A, B, Temp, I: Integer;
begin
  if N <= 0 then
    Exit(0);
  if N = 1 then
    Exit(1);
  A := 0;
  B := 1;
  for I := 2 to N do
  begin
    Temp := A + B;
    A := B;
    B := Temp;
  end;
  Result := B;
end;

function IsPrime(N: Integer): Boolean;
var
  I: Integer;
begin
  if N < 2 then
    Exit(False);
  if N = 2 then
    Exit(True);
  if N mod 2 = 0 then
    Exit(False);
  I := 3;
  while I * I <= N do
  begin
    if N mod I = 0 then
      Exit(False);
    I := I + 2;
  end;
  Result := True;
end;

var
  I, Count: Integer;
  S: string;
begin
  Count := 0;
  for I := 1 to 100 do
  begin
    if IsPrime(I) then
      Inc(Count);
  end;

  I := Fibonacci(10);
  S := ColorName(clBlue);

  repeat
    Dec(Count);
  until Count <= 0;
end.
