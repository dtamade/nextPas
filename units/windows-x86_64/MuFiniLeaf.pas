unit MuFiniLeaf;

{$mode objfpc}{$H+}

{ Batch 2: unit finalization body evidence. Init sets mark; finalization
  must lower into np_unit_fini_* (store), not empty ret-0 stub. }

interface

var
  GFiniMark: Integer;

function MuFiniRead: Integer;

implementation

function MuFiniRead: Integer;
begin
  Result := GFiniMark;
end;

initialization
  GFiniMark := 1;

finalization
  GFiniMark := GFiniMark + 40;

end.
