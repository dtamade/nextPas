{ objfpc}{+}
program comprehensive_typeconv_pass;
var I: Integer; C: Char; B: Byte;
begin
  I:=65; C:=Chr(I); if C<>'A' then Halt(1);
  C:='B'; I:=Ord(C); if I<>66 then Halt(2);
  I:=255; B:=Byte(I); if B<>255 then Halt(3);
  B:=128; I:=Integer(B); if I<>128 then Halt(4);
end.
