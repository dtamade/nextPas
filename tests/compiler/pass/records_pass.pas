{$mode objfpc}{$H+}
program test_records_pass;

type
  TPoint = record
    X, Y: LongInt;
  end;

  TRect = record
    Origin: TPoint;
    Width, Height: LongInt;
  end;

function MakePoint(AX, AY: LongInt): TPoint;
begin
  Result.X := AX;
  Result.Y := AY;
end;

function RectArea(const R: TRect): LongInt;
begin
  Result := R.Width * R.Height;
end;

var
  P: TPoint;
  R: TRect;
begin
  P := MakePoint(10, 20);
  if (P.X <> 10) or (P.Y <> 20) then
    Halt(1);

  R.Origin := P;
  R.Width := 100;
  R.Height := 50;
  if RectArea(R) <> 5000 then
    Halt(2);

  WriteLn('records OK');
end.
