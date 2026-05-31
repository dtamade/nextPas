program llvm_empty_class;
type
  TEmpty = class
    constructor Create;
    function Id: Integer; virtual;
  end;
constructor TEmpty.Create; begin end;
function TEmpty.Id: Integer; begin Result := 42; end;
var E: TEmpty;
begin
  E := TEmpty.Create;
  Halt(E.Id);
end.
