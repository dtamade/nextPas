program strength_red_edge_pass;

{ 强度削减边界测试 }

function TestMulBy16: Integer;
var
  X: Integer;
begin
  X := 5;
  TestMulBy16 := X * 16;    { 应削减为 X shl 4 → 80 }
end;

function TestDivBy8: Integer;
var
  X: Integer;
begin
  X := 256;
  TestDivBy8 := X div 8;    { 应削减为 X shr 3 → 32 }
end;

function TestMulNonPower2: Integer;
var
  X: Integer;
begin
  X := 7;
  TestMulNonPower2 := X * 3;  { 非 2 的幂，不应削减但结果正确 }
end;

function TestDivNonPower2: Integer;
var
  X: Integer;
begin
  X := 100;
  TestDivNonPower2 := X div 3;  { 非 2 的幂，不应削减但结果正确 }
end;

begin
  if TestMulBy16 <> 80 then Halt(1);
  if TestDivBy8 <> 32 then Halt(2);
  if TestMulNonPower2 <> 21 then Halt(3);
  if TestDivNonPower2 <> 33 then Halt(4);
end.
