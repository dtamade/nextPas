{ nextpas.compiler.sema.name_set.pas — Case-insensitive sorted string set for fast lookup }

unit nextpas.compiler.sema.name_set;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.core.collections.vec;

type
  TNameStringVec = specialize TVec<string>;

  { A case-insensitive sorted string set with O(log n) lookup.
    Names is session/process-long on the default heap (not phase scratch). }
  TNameSet = record
    Names: TNameStringVec;
  end;

{ Initialize a name set with the given capacity }
procedure NameSetInit(out ASet: TNameSet; ACapacity: LongInt);

{ Add a name to the set (must be lowercase) }
procedure NameSetAdd(var ASet: TNameSet; const AName: string);

{ Finalize the set — sort for binary search }
procedure NameSetFinalize(var ASet: TNameSet);

{ Free the set storage }
procedure NameSetFree(var ASet: TNameSet);

{ Check if a name exists in the set (case-insensitive) }
function NameSetContains(const ASet: TNameSet; const AName: string): Boolean;

implementation

{ ASCII-only lowercase — sufficient for Pascal identifiers }
function AsciiLowerCase(const S: string): string;
var
  I: LongInt;
  C: Char;
begin
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if (C >= 'A') and (C <= 'Z') then
      Result[I] := Chr(Ord(C) + 32)
    else
      Result[I] := C;
  end;
end;

procedure NameSetInit(out ASet: TNameSet; ACapacity: LongInt);
begin
  if ACapacity > 0 then
    ASet.Names := TNameStringVec.Create(SizeUInt(ACapacity))
  else
    ASet.Names := TNameStringVec.Create;
end;

procedure NameSetAdd(var ASet: TNameSet; const AName: string);
begin
  if ASet.Names = nil then
    ASet.Names := TNameStringVec.Create;
  ASet.Names.Push(AsciiLowerCase(AName));
end;

procedure NameSetFinalize(var ASet: TNameSet);
var
  I, J, N: LongInt;
  Temp: string;
begin
  if (ASet.Names = nil) or (ASet.Names.Count = 0) then
    Exit;

  N := LongInt(ASet.Names.Count);

  { Simple insertion sort — good enough for ~200 elements }
  for I := 1 to N - 1 do
  begin
    Temp := ASet.Names.Get(SizeUInt(I));
    J := I - 1;
    while (J >= 0) and (ASet.Names.Get(SizeUInt(J)) > Temp) do
    begin
      ASet.Names.GetPtr(SizeUInt(J + 1))^ := ASet.Names.Get(SizeUInt(J));
      Dec(J);
    end;
    ASet.Names.GetPtr(SizeUInt(J + 1))^ := Temp;
  end;

  { Remove duplicates }
  J := 0;
  for I := 1 to N - 1 do
  begin
    if ASet.Names.Get(SizeUInt(I)) <> ASet.Names.Get(SizeUInt(J)) then
    begin
      Inc(J);
      ASet.Names.GetPtr(SizeUInt(J))^ := ASet.Names.Get(SizeUInt(I));
    end;
  end;
  ASet.Names.Truncate(SizeUInt(J + 1));
end;

procedure NameSetFree(var ASet: TNameSet);
begin
  ASet.Names.Free;
  ASet.Names := nil;
end;

function NameSetContains(const ASet: TNameSet; const AName: string): Boolean;
var
  Lo, Hi, Mid: LongInt;
  Lower: string;
  MidVal: string;
begin
  Result := False;
  if (ASet.Names = nil) or (ASet.Names.Count = 0) then
    Exit;
  Lower := AsciiLowerCase(AName);
  Lo := 0;
  Hi := LongInt(ASet.Names.Count) - 1;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    MidVal := ASet.Names.Get(SizeUInt(Mid));
    if MidVal = Lower then
      Exit(True)
    else if MidVal < Lower then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;
end;

end.
