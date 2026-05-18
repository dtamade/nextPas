program Typed_const_pass;

{$mode objfpc}{$H+}

type
  TPoint = record
    X: Integer;
    Y: Integer;
  end;

const
  Origin: TPoint = (X: 0; Y: 0);
  MaxItems = 100;
  DefaultName = 'untitled';
  Digits: array[0..9] of Char = ('0','1','2','3','4','5','6','7','8','9');
  HexChars: set of Char = ['0'..'9', 'A'..'F', 'a'..'f'];

var
  P: TPoint;
  I: Integer;
begin
  P := Origin;
  I := MaxItems;
end.
