program Llvm_class_virtual;
type
  TShape = class
    FSide: Integer;
    constructor Create(ASide: Integer);
    function Area: Integer; virtual;
  end;
  TSquare = class(TShape)
    constructor Create(ASide: Integer);
    function Area: Integer; override;
  end;

constructor TShape.Create(ASide: Integer);
begin
  FSide := ASide;
end;

function TShape.Area: Integer;
begin
  Area := FSide;
end;

constructor TSquare.Create(ASide: Integer);
begin
  FSide := ASide;
end;

function TSquare.Area: Integer;
begin
  Area := FSide * FSide;
end;

var
  S: TSquare;
begin
  S := TSquare.Create(5);
  Halt(S.Area);
end.
