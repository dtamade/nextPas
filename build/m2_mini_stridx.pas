{$mode objfpc}{$H+}
program m2_mini_stridx;
{ llvm 执行面守卫(v2.35): 字符索引读=经 np_tstring_copy 物化 1 字符切片,
  写=经 np_tstring_setchar(CoW ensure-unique)。回归症状: 读退化为打印
  裸索引值; 写退化为整串字面量替换毁串; 共享堆缓冲被裸 store 腐坏。 }
var
  S, T: string;
begin
  S := 'abc';
  WriteLn(S[2]);
  S[1] := 'X';
  WriteLn(S);
  S := 'hello';
  S := S + ' w';
  T := S;
  S[1] := 'J';
  WriteLn(S);
  WriteLn(T);
end.
