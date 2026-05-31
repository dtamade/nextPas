program llvm_composite_pattern;
type
  TComponent = class
    FName: Integer;
    constructor Create(N: Integer);
    function Value: Integer; virtual;
  end;
  TLeaf = class(TComponent)
    FData: Integer;
    constructor Create(N, D: Integer);
    function Value: Integer; override;
  end;
  TComposite = class(TComponent)
    FChildren: array of Integer;
    FChildPtrs: array of TComponent;
    FCount: Integer;
    constructor Create(N: Integer);
    procedure Add(C: TComponent); virtual;
    function Value: Integer; override;
  end;

constructor TComponent.Create(N: Integer);
begin
  FName := N;
end;
function TComponent.Value: Integer;
begin
  Result := FName;
end;

constructor TLeaf.Create(N, D: Integer);
begin
  FName := N;
  FData := D;
end;
function TLeaf.Value: Integer;
begin
  Result := FData;
end;

constructor TComposite.Create(N: Integer);
begin
  FName := N;
  FCount := 0;
  SetLength(FChildren, 8);
end;

procedure TComposite.Add(C: TComponent);
begin
  FChildren[FCount] := C.Value;
  FCount := FCount + 1;
end;

function TComposite.Value: Integer;
var I, S: Integer;
begin
  S := 0;
  for I := 0 to FCount - 1 do
    S := S + FChildren[I];
  Result := S;
end;

var
  Root: TComposite;
  L1, L2, L3: TLeaf;
begin
  Root := TComposite.Create(0);
  L1 := TLeaf.Create(1, 10);
  L2 := TLeaf.Create(2, 20);
  L3 := TLeaf.Create(3, 30);
  Root.Add(L1);
  Root.Add(L2);
  Root.Add(L3);
  Halt(Root.Value);
end.
