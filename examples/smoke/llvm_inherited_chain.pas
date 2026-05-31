program llvm_inherited_chain;
type
  TA = class
    FVal: Integer;
    constructor Create(V: Integer);
    function Compute: Integer; virtual;
  end;
  TB = class(TA)
    constructor Create(V: Integer);
    function Compute: Integer; override;
  end;
  TC = class(TB)
    constructor Create(V: Integer);
    function Compute: Integer; override;
  end;

constructor TA.Create(V: Integer); begin FVal := V; end;
constructor TB.Create(V: Integer); begin FVal := V; end;
constructor TC.Create(V: Integer); begin FVal := V; end;

function TA.Compute: Integer;
begin
  Result := FVal;
end;

function TB.Compute: Integer;
begin
  Result := inherited Compute * 2;
end;

function TC.Compute: Integer;
begin
  Result := inherited Compute + 10;
end;

var C: TC;
begin
  C := TC.Create(3);
  Halt(C.Compute);
end.
