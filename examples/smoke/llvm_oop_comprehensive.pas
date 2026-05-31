program llvm_oop_comprehensive;
type
  TShape = class
    FArea: Integer;
    constructor Create(A: Integer);
    function Area: Integer; virtual;
  end;

  TShapeNode = class
    FShape: TShape;
    FNext: TShapeNode;
    constructor Create(S: TShape);
  end;

  TShapeList = class
    FHead: TShapeNode;
    FCount: Integer;
    constructor Create;
    procedure Add(S: TShape); virtual;
    function TotalArea: Integer; virtual;
    function Count: Integer; virtual;
  end;

constructor TShape.Create(A: Integer);
begin
  FArea := A;
end;

function TShape.Area: Integer;
begin
  Result := FArea;
end;

constructor TShapeNode.Create(S: TShape);
begin
  FShape := S;
end;

constructor TShapeList.Create;
begin
  FCount := 0;
end;

procedure TShapeList.Add(S: TShape);
var
  N: TShapeNode;
begin
  N := TShapeNode.Create(S);
  N.FNext := FHead;
  FHead := N;
  FCount := FCount + 1;
end;

function TShapeList.TotalArea: Integer;
var
  Cur: TShapeNode;
  S: Integer;
begin
  S := 0;
  Cur := FHead;
  while Cur <> nil do
  begin
    S := S + Cur.FShape.Area;
    Cur := Cur.FNext;
  end;
  Result := S;
end;

function TShapeList.Count: Integer;
begin
  Result := FCount;
end;

var
  List: TShapeList;
  S1, S2, S3: TShape;
begin
  List := TShapeList.Create;
  S1 := TShape.Create(27);
  S2 := TShape.Create(16);
  S3 := TShape.Create(12);
  List.Add(S1);
  List.Add(S2);
  List.Add(S3);
  Halt(List.TotalArea + List.Count);
end.
