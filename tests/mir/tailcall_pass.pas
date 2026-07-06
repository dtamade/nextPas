{ objfpc}{+}
program test_tailcall_unit;
{ Tail call 单元测试 — 尾递归检测 }
function IsTailCall(IsCall: Boolean; CallName, FuncName: string; ReturnsCallResult: Boolean): Boolean;
begin
  IsTailCall := IsCall and (CallName = FuncName) and ReturnsCallResult;
end;
begin
  if IsTailCall(True, 'fact', 'fact', True) <> True then Halt(1);
  if IsTailCall(True, 'fact', 'other', True) <> False then Halt(2);
  if IsTailCall(False, 'fact', 'fact', True) <> False then Halt(3);
  if IsTailCall(True, 'fact', 'fact', False) <> False then Halt(4);
end.
