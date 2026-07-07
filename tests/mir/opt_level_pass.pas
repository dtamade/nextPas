{ objfpc}{+}
program test_opt_level_unit;
{ 优化级别单元测试 }
type TMirOptLevel = (molO0, molO1, molO2);
function ParseOptLevel(const S: string): TMirOptLevel;
var LS: string; I: LongInt;
begin
  LS:=''; for I:=1 to Length(S) do LS:=LS+UpCase(S[I]);
  if LS='0' then ParseOptLevel:=molO0
  else if (LS='1') or (LS='O1') then ParseOptLevel:=molO1
  else ParseOptLevel:=molO2;
end;
function PassCountForLevel(Lvl: TMirOptLevel): LongInt;
begin
  case Lvl of
    molO0: PassCountForLevel:=1;
    molO1: PassCountForLevel:=6;
    molO2: PassCountForLevel:=12;
  end;
end;
begin
  if ParseOptLevel('0')<>molO0 then Halt(1);
  if ParseOptLevel('O1')<>molO1 then Halt(2);
  if ParseOptLevel('O2')<>molO2 then Halt(3);
  if PassCountForLevel(molO0)<>1 then Halt(4);
  if PassCountForLevel(molO1)<>6 then Halt(5);
  if PassCountForLevel(molO2)<>12 then Halt(6);
end.
