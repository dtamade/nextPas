{$mode objfpc}{$H+}
program test_control_flow_pass;
uses SysUtils;

var
  I, J, Sum: LongInt;
  Found: Boolean;
begin
  { nested for }
  Sum := 0;
  for I := 1 to 10 do
    for J := 1 to 10 do
      Inc(Sum, I * J);
  if Sum <> 3025 then Halt(1);

  { while with break }
  I := 0;
  while I < 100 do
  begin
    Inc(I);
    if I > 50 then Break;
  end;
  if I <> 51 then Halt(2);

  { repeat-until }
  I := 0;
  repeat
    Inc(I);
  until I >= 10;
  if I <> 10 then Halt(3);

  { case statement }
  for I := 1 to 5 do
  begin
    case I of
      1: Sum := 10;
      2: Sum := 20;
      3: Sum := 30;
    else
      Sum := 99;
    end;
    case I of
      1: if Sum <> 10 then Halt(4);
      2: if Sum <> 20 then Halt(5);
      3: if Sum <> 30 then Halt(6);
    else
      if Sum <> 99 then Halt(7);
    end;
  end;

  { try/except }
  Found := False;
  try
    raise Exception.Create('test error');
  except
    on E: Exception do
    begin
      if E.Message <> 'test error' then Halt(8);
      Found := True;
    end;
  end;
  if not Found then Halt(9);

  WriteLn('control flow OK');
end.
