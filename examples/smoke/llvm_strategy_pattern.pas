program llvm_strategy_pattern;
type
  TSorter = class
    constructor Create;
    function Compare(A, B: Integer): Integer; virtual; abstract;
  end;
  TAscending = class(TSorter)
    constructor Create;
    function Compare(A, B: Integer): Integer; override;
  end;
  TDescending = class(TSorter)
    constructor Create;
    function Compare(A, B: Integer): Integer; override;
  end;

constructor TSorter.Create; begin end;
constructor TAscending.Create; begin end;
constructor TDescending.Create; begin end;

function TAscending.Compare(A, B: Integer): Integer;
begin
  if A < B then
    Result := 1
  else
    Result := 0;
end;

function TDescending.Compare(A, B: Integer): Integer;
begin
  if A > B then
    Result := 1
  else
    Result := 0;
end;

function FindMin(S: TSorter; A, B, C: Integer): Integer;
begin
  Result := A;
  if S.Compare(B, Result) = 1 then
    Result := B;
  if S.Compare(C, Result) = 1 then
    Result := C;
end;

var
  Asc: TAscending;
  Desc: TDescending;
begin
  Asc := TAscending.Create;
  Desc := TDescending.Create;
  Halt(FindMin(Asc, 30, 12, 20) + FindMin(Desc, 30, 12, 20));
end.
