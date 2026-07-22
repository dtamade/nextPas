unit MuInitMid;

{$mode objfpc}{$H+}

{ Kernel multi-unit residual probe: mid unit depends on leaf and adds in init. }

interface

uses
  MuInitLeaf;

function MuTotal: Integer;

implementation

function MuTotal: Integer;
begin
  Result := MuGetAcc;
end;

initialization
  GMuAcc := GMuAcc + 30;

end.
