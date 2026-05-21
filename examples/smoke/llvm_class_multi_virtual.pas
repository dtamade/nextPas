program Llvm_class_multi_virtual;
type
  TShape = class
    FSide: Integer;
    constructor Create(ASide: Integer);
    function Area: Integer; virtual;
    function Perimeter: Integer; virtual;
  end;
  TSquare = class(TShape)
    constructor Create(ASide: Integer);
    function Area: Integer; override;
    function Perimeter: Integer; override;
  end;

constructor TShape.Create(ASide: Integer);
begin
  FSide := ASide;
end;

function TShape.Area: Integer;
begin
  Area := FSide;
end;

function TShape.Perimeter: Integer;
begin
  Perimeter := FSide;
end;

constructor TSquare.Create(ASide: Integer);
begin
  FSide := ASide;
end;

function TSquare.Area: Integer;
begin
  Area := FSide * FSide;
end;

function TSquare.Perimeter: Integer;
begin
  Perimeter := FSide * 4;
end;

var
  S: TSquare;
begin
  S := TSquare.Create(3);
  Halt(S.Area + S.Perimeter);
end.
