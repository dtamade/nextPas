program strength_red_pass;

{ 验证强度削减：昂贵操作替换为廉价操作 }

function TestMulBy2: Integer;
var
  X: Integer;
begin
  X := 42;
  TestMulBy2 := X * 2;    { 应削减为 X + X 或 shl 1 }
end;

function TestMulByPower2: Integer;
var
  X: Integer;
begin
  X := 10;
  TestMulByPower2 := X * 8;  { 应削减为 X shl 3 }
end;

function TestDivBy2: Integer;
var
  X: Integer;
begin
  X := 100;
  TestDivBy2 := X div 2;    { 应削减为 X shr 1 }
end;

function TestDivByPower2: Integer;
var
  X: Integer;
begin
  X := 64;
  TestDivByPower2 := X div 4;  { 应削减为 X shr 2 }
end;

begin
  if TestMulBy2 <> 84 then Halt(1);
  if TestMulByPower2 <> 80 then Halt(2);
  if TestDivBy2 <> 50 then Halt(3);
  if TestDivByPower2 <> 16 then Halt(4);
end.
