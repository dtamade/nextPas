program test_array_of_obj;
type
  TItem = class
    FVal: Integer;
    constructor Create(V: Integer);
    function GetVal: Integer; virtual;
  end;

constructor TItem.Create(V: Integer);
begin
  FVal := V;
end;

function TItem.GetVal: Integer;
begin
  Result := FVal;
end;

var
  Items: array of TItem;
  I, S: Integer;
begin
  SetLength(Items, 4);
  Items[0] := TItem.Create(10);
  Items[1] := TItem.Create(11);
  Items[2] := TItem.Create(12);
  Items[3] := TItem.Create(9);
  S := 0;
  for I := 0 to 3 do
    S := S + Items[I].GetVal;
  Halt(S);
end.
