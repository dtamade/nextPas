program llvm_visitor_pattern;
type
  TElement = class
    FVal: Integer;
    constructor Create(V: Integer);
    function Accept(Multiplier: Integer): Integer; virtual;
  end;
  TDoubler = class(TElement)
    constructor Create(V: Integer);
    function Accept(Multiplier: Integer): Integer; override;
  end;
  TTripler = class(TElement)
    constructor Create(V: Integer);
    function Accept(Multiplier: Integer): Integer; override;
  end;

constructor TElement.Create(V: Integer);
begin
  FVal := V;
end;
function TElement.Accept(Multiplier: Integer): Integer;
begin
  Result := FVal * Multiplier;
end;
constructor TDoubler.Create(V: Integer);
begin
  FVal := V;
end;
function TDoubler.Accept(Multiplier: Integer): Integer;
begin
  Result := FVal * Multiplier * 2;
end;
constructor TTripler.Create(V: Integer);
begin
  FVal := V;
end;
function TTripler.Accept(Multiplier: Integer): Integer;
begin
  Result := FVal * Multiplier * 3;
end;

function Visit(E: TElement; M: Integer): Integer;
begin
  Result := E.Accept(M);
end;

var
  D: TDoubler;
  T: TTripler;
  E: TElement;
begin
  D := TDoubler.Create(5);
  T := TTripler.Create(8);
  E := TElement.Create(8);
  Halt(Visit(D, 1) + Visit(T, 1) + Visit(E, 1));
end.
