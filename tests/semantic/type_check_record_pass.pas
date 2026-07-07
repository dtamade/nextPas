{$mode objfpc}{$H+}
program type_check_record_pass;

{ 类型检查：record 类型操作 }

type
  TPoint = record
    X, Y: Integer;
  end;

  TRect = record
    TopLeft, BottomRight: TPoint;
  end;

var
  P: TPoint;
  R: TRect;
begin
  P.X := 10;
  P.Y := 20;
  if P.X <> 10 then Halt(1);
  if P.Y <> 20 then Halt(2);

  R.TopLeft.X := 1;
  R.TopLeft.Y := 2;
  R.BottomRight.X := 3;
  R.BottomRight.Y := 4;
  if R.TopLeft.X <> 1 then Halt(3);
  if R.BottomRight.Y <> 4 then Halt(4);
end.
