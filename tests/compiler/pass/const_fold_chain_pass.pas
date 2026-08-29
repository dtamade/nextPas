program ConstFoldChainPass;

{$mode objfpc}{$H+}

const
  A = 5;
  B = A + 10;
  C = B * 2;

var
  LSum: Integer;

begin
  LSum := A + B + C;
  // A=5 B=15 C=30 sum=50
  if LSum <> 50 then
  begin
    WriteLn('FAIL: const fold chain got ', LSum);
    Halt(1);
  end;
  WriteLn('const-fold-chain ok ', LSum);
end.
