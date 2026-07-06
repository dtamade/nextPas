{$mode objfpc}{$H+}
program hir_lowering_bitwise_pass;

{ HIR lowering：位运算 }

var
  A, B, R: Integer;
begin
  A := $0F;  { 00001111 }
  B := $F0;  { 11110000 }
  R := A and B;  if R <> 0 then Halt(1);
  R := A or B;   if R <> $FF then Halt(2);
  R := A xor B;  if R <> $FF then Halt(3);
  R := not A;    if R <> -16 then Halt(4);  { ~15 = -16 in 2's complement }
  R := A shl 4;  if R <> $F0 then Halt(5);
  R := B shr 4;  if R <> $0F then Halt(6);
end.
