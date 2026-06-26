program inline_record_type_pass;

{$mode objfpc}{$H+}

type
  TOuter = class
  public
    Items: array of record
      Name: string;
      Value: LongInt;
    end;
    Count: LongInt;
  end;

var
  Obj: TOuter;
begin
  Obj := TOuter.Create;
  try
    Obj.Count := 42;
    SetLength(Obj.Items, 2);
    Obj.Items[0].Name := 'hello';
    Obj.Items[0].Value := 1;
    Obj.Items[1].Name := 'world';
    Obj.Items[1].Value := 2;
    if Obj.Count <> 42 then
      Halt(1);
    if Obj.Items[0].Name <> 'hello' then
      Halt(2);
    if Obj.Items[1].Value <> 2 then
      Halt(3);
  finally
    Obj.Free;
  end;
end.
