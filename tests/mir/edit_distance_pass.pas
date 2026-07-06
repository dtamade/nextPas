{ objfpc}{+}
program test_edit_distance_unit;
{ 编辑距离单元测试 — Levenshtein 算法 }
function EditDistance(const A, B: string): LongInt;
var I,J,Cost,LenA,LenB: LongInt;
  D: array[0..20,0..20] of LongInt;
begin
  LenA:=Length(A); LenB:=Length(B);
  if LenA=0 then Exit(LenB); if LenB=0 then Exit(LenA);
  for I:=0 to LenA do D[I][0]:=I;
  for J:=0 to LenB do D[0][J]:=J;
  for I:=1 to LenA do for J:=1 to LenB do begin
    if A[I]=B[J] then Cost:=0 else Cost:=1;
    D[I][J]:=D[I-1][J]+1;
    if D[I][J-1]+1<D[I][J] then D[I][J]:=D[I][J-1]+1;
    if D[I-1][J-1]+Cost<D[I][J] then D[I][J]:=D[I-1][J-1]+Cost;
  end;
  EditDistance:=D[LenA][LenB];
end;
begin
  if EditDistance('abc','abc')<>0 then Halt(1);
  if EditDistance('abc','abd')<>1 then Halt(2);
  if EditDistance('abc','xyz')<>3 then Halt(3);
  if EditDistance('','abc')<>3 then Halt(4);
  if EditDistance('kitten','sitting')<>3 then Halt(5);
end.
