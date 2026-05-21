program Llvm_class_polymorphic;
type
  TShape = class
    FSide: Integer;
    constructor Create(ASide: Integer);
    function Area: Integer; virtual;
  end;
  TRect = class(TShape)
    FHeight: Integer;
    constructor Create(AW, AH: Integer);
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

constructor TRect.Create(AW, AH: Integer);
begin
  inherited Create(AW);
  FHeight := AH;
end;

function TRect.Area: Integer;
begin
  Area := FSide * FHeight;
end;

var
  S: TShape;
begin
  S := TRect.Create(6, 7);
  Halt(S.Area);
end.
