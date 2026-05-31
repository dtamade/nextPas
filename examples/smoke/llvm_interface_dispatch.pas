program llvm_interface_dispatch;
type
  ICounter = interface
    function Count: Integer;
  end;
  TImpl = class(TObject, ICounter)
    function Count: Integer;
  end;

function TImpl.Count: Integer;
begin
  Count := 42;
end;

var
  C: ICounter;
begin
  C := TImpl.Create;
  Halt(C.Count);
end.
