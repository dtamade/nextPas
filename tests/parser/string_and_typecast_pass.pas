program String_and_typecast_pass;

{$mode objfpc}{$H+}

type
  TByteArray = array of Byte;

function IntToStr(I: Integer): string;
begin
  Str(I, Result);
end;

function StrToInt(const S: string): Integer;
var
  Code: Integer;
begin
  Val(S, Result, Code);
end;

var
  S: string;
  I: Integer;
  B: Byte;
  Arr: TByteArray;
begin
  S := 'Hello' + ' ' + 'World';
  I := Length(S);
  B := Byte(I);
  I := Integer(B);

  S := IntToStr(42);
  I := StrToInt('123');

  SetLength(Arr, 3);
  Arr[0] := Byte(65);
  Arr[1] := Byte(66);
  Arr[2] := Byte(67);

  if I > 0 then
  begin
    S := IntToStr(I);
    if Length(S) > 0 then
      I := Ord(S[1]);
  end;
end.
