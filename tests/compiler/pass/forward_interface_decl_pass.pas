program forward_interface_decl_pass;

{$mode objfpc}{$H+}

type
  IBenchResults = interface;

  IBenchContext = interface
    ['{11111111-1111-1111-1111-111111111111}']
    procedure SetBytes(ABytes: Int64);
    function GetName: string;
  end;

  IBenchResults = interface
    ['{22222222-2222-2222-2222-222222222222}']
    function GetCount: Integer;
  end;

  TBenchResults = class(TInterfacedObject, IBenchResults)
  public
    function GetCount: Integer;
  end;

function TBenchResults.GetCount: Integer;
begin
  Result := 7;
end;

var
  Results: IBenchResults;
begin
  Results := TBenchResults.Create;
  if Results.GetCount <> 7 then
    Halt(1);
end.
