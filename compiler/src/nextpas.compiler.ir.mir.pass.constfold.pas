{**
 * nextpas.compiler.ir.mir.pass.constfold.pas — MIR Constant Folding Pass
 *
 * 编译时计算常量表达式。
 *
 * 模式：
 *   %1 = const 2
 *   %2 = const 3
 *   %3 = %1 + %2       →   %3 = const 5
 *
 * 支持的操作：
 *   - 算术：+ - * / mod
 *   - 位运算：and or xor shl shr
 *   - 比较：= <> < <= > >=
 *   - 一元：neg, not
 *
 * 对标：rustc mir::transform::const_prop
 *}

unit nextpas.compiler.ir.mir.pass.constfold;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize;

type
  TMirConstFoldPass = class(TInterfacedObject, IMirOptimizationPass)
  public
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

function TMirConstFoldPass.Name: string;
begin
  Result := 'const-fold';
end;

{ 尝试对二元操作进行常量折叠 }
function TryFoldBinary(
  const ALhs, ARhs: TMirOperand;
  const AOp: TMirOp;
  out AResult: TMirOperand
): Boolean;
var
  L, R: Int64;
  UL, UR: QWord;
  Val: Int64;
  UVal: QWord;
  Cmp: Boolean;
begin
  Result := False;

  if (ALhs.Kind <> mokConst) or (ARhs.Kind <> mokConst) then
    Exit;

  L := ALhs.ConstVal.IntVal;
  R := ARhs.ConstVal.IntVal;
  UL := QWord(L);
  UR := QWord(R);

  case AOp of
    moAdd: Val := L + R;
    moSub: Val := L - R;
    moMul: Val := L * R;
    moSDiv: if R <> 0 then Val := L div R else Exit;
    moUDiv: if UR <> 0 then UVal := UL div UR else Exit;
    moSRem: if R <> 0 then Val := L mod R else Exit;
    moURem: if UR <> 0 then UVal := UL mod UR else Exit;
    moAnd: Val := L and R;
    moOr:  Val := L or R;
    moXor: Val := L xor R;
    moShl: Val := L shl (R and 63);
    moLShr: UVal := UL shr (UR and 63);
    moAShr: Val := L shr (R and 63);
    moEq:  Cmp := L = R;
    moNe:  Cmp := L <> R;
    moSLt: Cmp := L < R;
    moULt: Cmp := QWord(L) < QWord(R);
    moSLe: Cmp := L <= R;
    moULe: Cmp := QWord(L) <= QWord(R);
    else
      Exit;
  end;

  Result := True;
  AResult.Kind := mokConst;
  AResult.BitWidth := ALhs.BitWidth;
  AResult.IsSigned := ALhs.IsSigned;

  case AOp of
    moEq, moNe, moSLt, moULt, moSLe, moULe:
      begin
        AResult.ConstVal.IntVal := Ord(Cmp);
        AResult.BitWidth := 1;
      end;
    moUDiv, moURem, moLShr:
      AResult.ConstVal.IntVal := Int64(UVal);
    else
      AResult.ConstVal.IntVal := Val;
  end;
end;

{ 尝试对一元操作进行常量折叠 }
function TryFoldUnary(
  const ASrc: TMirOperand;
  const AOp: TMirOp;
  out AResult: TMirOperand
): Boolean;
begin
  Result := False;
  if ASrc.Kind <> mokConst then
    Exit;

  AResult.Kind := mokConst;
  AResult.BitWidth := ASrc.BitWidth;
  AResult.IsSigned := ASrc.IsSigned;

  case AOp of
    moNeg: AResult.ConstVal.IntVal := -ASrc.ConstVal.IntVal;
    moNot: AResult.ConstVal.IntVal := not ASrc.ConstVal.IntVal;
    else
      Exit;
  end;
  Result := True;
end;

function TMirConstFoldPass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx, StmtIdx: LongInt;
  Fn: TMirFunction;
  Stmt: TMirStmt;
  Folded: TMirOperand;
  Changed: Boolean;
  TotalFolds: LongInt;
begin
  Result := True;
  TotalFolds := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FuncIdx);
    Changed := True;

    { Iterate to fixed-point (folded constants may enable more folding) }
    while Changed do
    begin
      Changed := False;

      if Fn.Blocks <> nil then
      for BlkIdx := 0 to LongInt(Fn.Blocks.Count) - 1 do
      begin
        if Fn.Blocks[SizeUInt(BlkIdx)].Stmts <> nil then
          for StmtIdx := 0 to LongInt(Fn.Blocks[SizeUInt(BlkIdx)].Stmts.Count) - 1 do
        begin
          if not AModule.GetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt) then
            Continue;

          case Stmt.Kind of
            mskBinary:
              if TryFoldBinary(Stmt.Lhs, Stmt.Rhs, Stmt.Op, Folded) then
              begin
                Stmt.Kind := mskAssign;
                Stmt.Src := Folded;
                AModule.SetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt);
                Changed := True;
                Inc(TotalFolds);
              end;

            mskUnary:
              if TryFoldUnary(Stmt.Src, Stmt.Op, Folded) then
              begin
                Stmt.Kind := mskAssign;
                Stmt.Src := Folded;
                AModule.SetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt);
                Changed := True;
                Inc(TotalFolds);
              end;
          end;
        end;
      end;
    end;
  end;

  { Success even if no folds — pass ran correctly }
  Result := True;
end;

end.
