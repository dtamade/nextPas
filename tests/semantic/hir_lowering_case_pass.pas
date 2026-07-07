{$mode objfpc}{$H+}
program hir_lowering_case_pass;

{ HIR lowering：case 语句 }

function DayName(D: Integer): string;
begin
  case D of
    1: DayName := 'Mon';
    2: DayName := 'Tue';
    3: DayName := 'Wed';
    4: DayName := 'Thu';
    5: DayName := 'Fri';
    6: DayName := 'Sat';
    7: DayName := 'Sun';
  else
    DayName := 'Unknown';
  end;
end;

var
  S: string;
begin
  S := DayName(1);
  if S <> 'Mon' then Halt(1);
  S := DayName(7);
  if S <> 'Sun' then Halt(2);
  S := DayName(99);
  if S <> 'Unknown' then Halt(3);
end.
