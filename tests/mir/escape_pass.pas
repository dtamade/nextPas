{ objfpc}{+}
program test_escape_unit;
{ Escape analysis 单元测试 — 逃逸标记 }
type TEscapeFlag = (efNone, efStored, efPassed, efReturned);
     TEscapeFlags = set of TEscapeFlag;
function ValueEscapes(Flags: TEscapeFlags): Boolean;
begin ValueEscapes := Flags <> [efNone]; end;
begin
  if ValueEscapes([efNone]) <> False then Halt(1);
  if ValueEscapes([efStored]) <> True then Halt(2);
  if ValueEscapes([efPassed]) <> True then Halt(3);
  if ValueEscapes([efReturned]) <> True then Halt(4);
  if ValueEscapes([efStored, efPassed]) <> True then Halt(5);
end.
