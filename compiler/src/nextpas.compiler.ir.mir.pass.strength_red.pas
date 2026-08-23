{**
 * nextpas.compiler.ir.mir.pass.strength_red.pas — MIR Strength Reduction Pass
 *
 * 将高成本操作替换为等价低成本操作。
 *
 * 模式：
 *   - x * 2  → x + x
 *   - x * 2^n → x shl n
 *   - x / 2^n → x shr n (unsigned) or x ashr n (signed)
 *   - x mod 2^n → x and (2^n - 1)
 *
 * 对标：LLVM InstCombine, rustc mir::transform
 *}

unit nextpas.compiler.ir.mir.pass.strength_red;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize;

type
  TMirStrengthRedPass = class(TInterfacedObject, IMirOptimizationPass)
  public
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

function TMirStrengthRedPass.Name: string;
begin
  Result := 'strength-reduction';
end;

{ 检查常量是否是 2 的幂 }
function IsPowerOfTwo(AVal: Int64; out AShift: LongInt): Boolean;
var
  N: Int64;
begin
  if AVal <= 0 then
    Exit(False);
  N := AVal;
  AShift := 0;
  while (N and 1) = 0 do
  begin
    Inc(AShift);
    N := N shr 1;
  end;
  Result := (N = 1) and (AShift > 0);
end;

function TMirStrengthRedPass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx, StmtIdx: LongInt;
  Fn: TMirFunction;
  Stmt: TMirStmt;
  ConstVal: Int64;
  ShiftAmt: LongInt;
  TotalReds: LongInt;
begin
  Result := True;
  TotalReds := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FuncIdx);

    if Fn.Blocks <> nil then
      for BlkIdx := 0 to LongInt(Fn.Blocks.Count) - 1 do
      if Fn.Blocks[SizeUInt(BlkIdx)].Stmts <> nil then
          for StmtIdx := 0 to LongInt(Fn.Blocks[SizeUInt(BlkIdx)].Stmts.Count) - 1 do
      begin
        if not AModule.GetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt) then
          Continue;

        if Stmt.Kind <> mskBinary then
          Continue;

        { x * 2^n → x shl n }
        if (Stmt.Op = moMul) and (Stmt.Rhs.Kind = mokConst) then
        begin
          ConstVal := Stmt.Rhs.ConstVal.IntVal;
          if IsPowerOfTwo(ConstVal, ShiftAmt) then
          begin
            Stmt.Op := moShl;
            Stmt.Rhs.ConstVal.IntVal := ShiftAmt;
            AModule.SetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt);
            Inc(TotalReds);
            Continue;
          end;
        end;

        { x / 2^n → x shr n (unsigned) }
        if ((Stmt.Op = moUDiv) or (Stmt.Op = moSDiv))
          and (Stmt.Rhs.Kind = mokConst) then
        begin
          ConstVal := Stmt.Rhs.ConstVal.IntVal;
          if IsPowerOfTwo(ConstVal, ShiftAmt) then
          begin
            if Stmt.Op = moUDiv then
              Stmt.Op := moLShr
            else
              Stmt.Op := moAShr;
            Stmt.Rhs.ConstVal.IntVal := ShiftAmt;
            AModule.SetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt);
            Inc(TotalReds);
          end;
        end;
      end;
  end;
end;

end.
