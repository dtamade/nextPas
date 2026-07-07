{$mode objfpc}{$H+}
program hir_lowering_loop_pass;

{ HIR lowering：循环结构 }

var
  I, Sum, Count: Integer;
begin
  { for-to }
  Sum := 0;
  for I := 1 to 10 do
    Sum := Sum + I;
  if Sum <> 55 then Halt(1);

  { for-downto }
  Count := 0;
  for I := 10 downto 1 do
    Count := Count + 1;
  if Count <> 10 then Halt(2);

  { while }
  I := 0;
  Sum := 0;
  while I < 5 do
  begin
    I := I + 1;
    Sum := Sum + I;
  end;
  if Sum <> 15 then Halt(3);

  { repeat-until }
  I := 0;
  Sum := 0;
  repeat
    I := I + 1;
    Sum := Sum + I;
  until I >= 5;
  if Sum <> 15 then Halt(4);
end.
