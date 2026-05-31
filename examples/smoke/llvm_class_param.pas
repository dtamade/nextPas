program Llvm_class_param;
type
  TShape = class
    constructor Create;
    function Area: Integer; virtual;
  end;
  TSquare = class(TShape)
    FSide: Integer;
    constructor Create(S: Integer);
    function Area: Integer; override;
  end;
  TRect = class(TShape)
    FW, FH: Integer;
    constructor Create(W, H: Integer);
    function Area: Integer; override;
  end;

constructor TShape.Create;
begin
end;

function TShape.Area: Integer;
begin
  Result := 0;
end;

constructor TSquare.Create(S: Integer);
begin
  FSide := S;
end;

function TSquare.Area: Integer;
begin
  Result := FSide * FSide;
end;

constructor TRect.Create(W, H: Integer);
begin
  FW := W;
  FH := H;
end;

function TRect.Area: Integer;
begin
  Result := FW * FH;
end;

function TotalArea(A, B: TShape): Integer;
begin
  Result := A.Area + B.Area;
end;

var
  S: TSquare;
  R: TRect;
begin
  S := TSquare.Create(5);
  R := TRect.Create(17, 1);
  Halt(TotalArea(S, R));
end.
