// unit_lifecycle_pass.pas — Gate 2 验证：unit initialization/finalization 编译
//
// 验证项：
// 1. unit 有 initialization section → 编译为 np_unit_init_<name>
// 2. unit 有 finalization section → 编译为 np_unit_fini_<name>
// 3. init/fini 在 _start 中以拓扑序直接调用 (替代 @llvm.global_ctors/dtors)
// 4. init/fini 中的语句被正确编译

program unit_lifecycle_pass;

uses
  test_unit_lifecycle;

var
  Count: LongInt;
begin
  Count := GetInitCount;
  if Count <> 42 then
    Halt(1);
  WriteLn('OK: init executed, count=', Count);
end.
