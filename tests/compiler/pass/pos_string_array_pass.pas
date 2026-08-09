{$mode objfpc}{$H+}
program test_pos_string_array_pass;

{ Pos() haystack/needle forms targeted by the L3 'tsload' encoding:
  string-array element haystack (local dynarray / open-array param / class
  field array) and const-identifier needle (DirectorySeparator). Native
  golden: host FPC defines the expected 1-based Pos results. }

type
  TStrArr = array of string;

  TBag = class
  public
    FItems: TStrArr;
    function FindEq: LongInt;
  end;

function TBag.FindEq: LongInt;
var
  I: LongInt;
begin
  Result := -1;
  for I := 0 to Length(FItems) - 1 do
    if Pos('=', FItems[I]) > 0 then
      Exit(I);
end;

function FindIn(const AItems: TStrArr): LongInt;
var
  I: LongInt;
begin
  Result := -1;
  for I := 0 to Length(AItems) - 1 do
    if Pos('=', AItems[I]) > 0 then
      Exit(I);
end;

var
  Arr: TStrArr;
  Bag: TBag;
  S: string;
begin
  SetLength(Arr, 3);
  Arr[0] := 'alpha';
  Arr[1] := 'beta=1';
  Arr[2] := 'x=y';

  { open-array/formal haystack }
  if FindIn(Arr) <> 1 then Halt(1);

  { local dynarray element haystack }
  if Pos('=', Arr[2]) <> 2 then Halt(2);
  if Pos('=', Arr[0]) <> 0 then Halt(3);

  { class field array haystack }
  Bag := TBag.Create;
  Bag.FItems := Arr;
  if Bag.FindEq <> 1 then Halt(4);
  Bag.Free;

  { const-identifier needle }
  S := 'a' + DirectorySeparator + 'b';
  if Pos(DirectorySeparator, S) <> 2 then Halt(5);
end.
