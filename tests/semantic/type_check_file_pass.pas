{$mode objfpc}{$H+}
program type_check_file_pass;

{ 类型检查：文件类型 }

var
  F: Text;
  S: string;
begin
  Assign(F, '/dev/null');
  Rewrite(F);
  WriteLn(F, 'test');
  Close(F);
  { 只需要能编译运行即可 }
end.
