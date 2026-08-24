{$mode objfpc}{$H+}
program m2_mini_valcat;
{ llvm 执行面守卫(v2.34): 值位置 concat 表达式作 Write/WriteLn 实参必须
  物化 concat 临时走 write_str_var。回归症状(漏入 write-int 时): 打印
  np_tstring_data 指针整数加法值与字符序数和。 }
var
  P, Q: string;
begin
  P := 'John';
  Q := 'Doe';
  WriteLn(P + Q);
  WriteLn(P + ' ' + Q);
  WriteLn('x' + P);
  WriteLn(P + '!');
end.
