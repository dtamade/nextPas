program llvm_interface_is;
type
  ICounter = interface
    function Count: Integer;
  end;
  TImpl = class(TObject, ICounter)
    function Count: Integer;
  end;

function TImpl.Count: Integer;
begin
  Count := 1;
end;

var
  O: TImpl;
  R: Integer;
begin
  O := TImpl.Create;
  R := 0;
  if O is ICounter then
    R := 42;
  Halt(R);
end.
