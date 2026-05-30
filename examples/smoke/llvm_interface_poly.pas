program llvm_interface_poly;
type
  IShape = interface
    function Area: Integer;
  end;
  TRect = class(TObject, IShape)
    FW, FH: Integer;
    constructor Create(W, H: Integer);
    function Area: Integer;
  end;
  TCircle = class(TObject, IShape)
    FR: Integer;
    constructor Create(R: Integer);
    function Area: Integer;
  end;

constructor TRect.Create(W, H: Integer);
begin
  FW := W;
  FH := H;
end;

function TRect.Area: Integer;
begin
  Area := FW * FH;
end;

constructor TCircle.Create(R: Integer);
begin
  FR := R;
end;

function TCircle.Area: Integer;
begin
  Area := 3 * FR * FR;
end;

var
  S: IShape;
  Total: Integer;
begin
  Total := 0;
  S := TRect.Create(5, 4);
  Total := Total + S.Area;
  S := TCircle.Create(3);
  Total := Total + S.Area;
  Halt(Total);
end.
