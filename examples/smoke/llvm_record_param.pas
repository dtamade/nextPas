program llvm_record_param;
type
  TRect = record
    X, Y, W, H: Integer;
  end;

function MakeRect(AX, AY, AW, AH: Integer): TRect;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.W := AW;
  Result.H := AH;
end;

function Area(R: TRect): Integer;
begin
  Result := R.W * R.H;
end;

function Perimeter(R: TRect): Integer;
begin
  Result := (R.W + R.H) * 2;
end;

var R: TRect;
begin
  R := MakeRect(0, 0, 6, 4);
  Halt(Area(R) + Perimeter(R));
end.
