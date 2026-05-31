program test_except_obj;
type
  TError = class
    FCode: Integer;
    constructor Create(Code: Integer);
    function GetCode: Integer; virtual;
  end;

constructor TError.Create(Code: Integer);
begin
  FCode := Code;
end;

function TError.GetCode: Integer;
begin
  Result := FCode;
end;

var
  R: Integer;
  E: TError;
begin
  R := 0;
  try
    raise TError.Create(42);
  except
    E := ExceptObject;
    R := E.GetCode;
  end;
  Halt(R);
end.
