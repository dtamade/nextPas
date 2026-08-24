{$mode objfpc}{$H+}
program m2_mini_globstr;
{ llvm 执行面守卫(v2.32): 全局字符串变量必须是内联 24B TString 存储。
  回归症状(存储退化为 8B ptr 槽时): 每次赋值溢出踩相邻全局——循环变
  量 I 打印错值、循环轮数漂移、整型全局 N 被腐坏。 }
var
  S: string;
  I: Integer;
  N: Integer;
begin
  S := 'abc';
  N := 42;
  for I := 1 to 3 do
  begin
    S := S + 'x';
    WriteLn(I, ':', S, ':', Length(S));
  end;
  WriteLn('N=', N);
end.
