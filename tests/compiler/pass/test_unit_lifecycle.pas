// test_unit_lifecycle.pas — 单元文件：包含 initialization/finalization section
//
// 用于 unit_lifecycle_pass.pas 测试

unit test_unit_lifecycle;

interface

function GetInitCount: LongInt;

implementation

var
  InitCount: LongInt;

function GetInitCount: LongInt;
begin
  GetInitCount := InitCount;
end;

initialization
  InitCount := 42;

finalization
  InitCount := 0;

end.
