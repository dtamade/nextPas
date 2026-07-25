unit MuInitLeaf;

{$mode objfpc}{$H+}

{ Kernel multi-unit residual probe: leaf unit with initialization side effect. }

interface

var
  GMuAcc: Integer;

function MuGetAcc: Integer;

implementation

function MuGetAcc: Integer;
begin
  Result := GMuAcc;
end;

initialization
  GMuAcc := 3;

end.
