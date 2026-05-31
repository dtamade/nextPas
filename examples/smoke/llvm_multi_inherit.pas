program llvm_multi_inherit;
type
  TA = class
    FA: Integer;
    constructor Create(V: Integer);
    function GetA: Integer; virtual;
  end;
  TB = class(TA)
    FB: Integer;
    constructor Create(A, B: Integer);
    function GetB: Integer; virtual;
  end;
  TC = class(TB)
    FC: Integer;
    constructor Create(A, B, C: Integer);
    function GetC: Integer; virtual;
    function Sum: Integer; virtual;
  end;

constructor TA.Create(V: Integer); begin FA := V; end;
function TA.GetA: Integer; begin Result := FA; end;
constructor TB.Create(A, B: Integer); begin FA := A; FB := B; end;
function TB.GetB: Integer; begin Result := FB; end;
constructor TC.Create(A, B, C: Integer); begin FA := A; FB := B; FC := C; end;
function TC.GetC: Integer; begin Result := FC; end;
function TC.Sum: Integer; begin Result := GetA + GetB + GetC; end;

var C: TC;
begin
  C := TC.Create(10, 20, 30);
  Halt(C.Sum);
end.
