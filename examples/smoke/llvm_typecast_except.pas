program test_cast_exc;
type
  TMyExc = class
    FCode: Integer;
    constructor Create(C: Integer);
    function GetCode: Integer; virtual;
  end;

constructor TMyExc.Create(C: Integer); begin FCode := C; end;
function TMyExc.GetCode: Integer; begin Result := FCode; end;

var R: Integer;
    E: TMyExc;
begin
  R := 0;
  try
    raise TMyExc.Create(42);
  except
    E := TMyExc(ExceptObject);
    R := E.GetCode;
  end;
  Halt(R);
end.
