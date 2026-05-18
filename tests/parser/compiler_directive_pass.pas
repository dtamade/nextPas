program Compiler_directive_pass;

{$mode objfpc}{$H+}
{$OPTIMIZATION ON}

var
  X: Integer;
begin
  {$HINTS OFF}
  X := 42;
  {$HINTS ON}
end.
