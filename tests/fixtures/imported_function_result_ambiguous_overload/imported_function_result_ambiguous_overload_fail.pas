program ImportedFunctionResultAmbiguousOverloadFail;

uses HelperA, HelperB;

function Count: Integer;
begin
end;

begin
  Pick(Count);
end.
