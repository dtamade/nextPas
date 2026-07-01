{ np_sema_name_set.pas — Case-insensitive sorted string set for fast lookup }

unit np_sema_name_set;

{$mode objfpc}{$H+}

interface

type
  { A case-insensitive sorted string set with O(log n) lookup }
  TNameSet = record
    Names: array of string;
    Count: LongInt;
  end;

{ Initialize a name set with the given capacity }
procedure NameSetInit(out ASet: TNameSet; ACapacity: LongInt);

{ Add a name to the set (must be lowercase) }
procedure NameSetAdd(var ASet: TNameSet; const AName: string);

{ Finalize the set — sort for binary search }
procedure NameSetFinalize(var ASet: TNameSet);

{ Check if a name exists in the set (case-insensitive) }
function NameSetContains(const ASet: TNameSet; const AName: string): Boolean;

implementation

uses
  SysUtils;

procedure NameSetInit(out ASet: TNameSet; ACapacity: LongInt);
begin
  SetLength(ASet.Names, ACapacity);
  ASet.Count := 0;
end;

procedure NameSetAdd(var ASet: TNameSet; const AName: string);
begin
  if ASet.Count >= Length(ASet.Names) then
    SetLength(ASet.Names, ASet.Count + 64);
  ASet.Names[ASet.Count] := LowerCase(AName);
  Inc(ASet.Count);
end;

procedure NameSetFinalize(var ASet: TNameSet);
var
  I, J: LongInt;
  Temp: string;
begin
  { Simple insertion sort — good enough for ~200 elements }
  for I := 1 to ASet.Count - 1 do
  begin
    Temp := ASet.Names[I];
    J := I - 1;
    while (J >= 0) and (ASet.Names[J] > Temp) do
    begin
      ASet.Names[J + 1] := ASet.Names[J];
      Dec(J);
    end;
    ASet.Names[J + 1] := Temp;
  end;
  { Remove duplicates }
  J := 0;
  for I := 1 to ASet.Count - 1 do
  begin
    if ASet.Names[I] <> ASet.Names[J] then
    begin
      Inc(J);
      ASet.Names[J] := ASet.Names[I];
    end;
  end;
  ASet.Count := J + 1;
end;

function NameSetContains(const ASet: TNameSet; const AName: string): Boolean;
var
  Lo, Hi, Mid: LongInt;
  Lower: string;
begin
  Result := False;
  if ASet.Count = 0 then
    Exit;
  Lower := LowerCase(AName);
  Lo := 0;
  Hi := ASet.Count - 1;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if ASet.Names[Mid] = Lower then
      Exit(True)
    else if ASet.Names[Mid] < Lower then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;
end;

end.
