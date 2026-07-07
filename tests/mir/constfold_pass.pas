{$mode objfpc}{$H+}
program test_constfold_unit;

{ MIR ConstFold pass 单元测试 — 直接测试常量折叠逻辑 }

type
  TMirOperandKind = (mokLocal, mokMove, mokConst);
  TMirOp = (moAdd, moSub, moMul, moSDiv, moUDiv, moSRem, moURem,
    moNeg, moNot, moAnd, moOr, moXor, moShl, moLShr, moAShr,
    moEq, moNe, moSLt, moULt, moSLe, moULe);

  TMirConst = record
    case Byte of
      0: (IntVal: Int64);
      1: (FloatVal: Double);
      2: (BoolVal: Boolean);
  end;

  TMirOperand = record
    Kind: TMirOperandKind;
    Value: LongInt;
    ConstVal: TMirConst;
    BitWidth: LongInt;
    IsSigned: Boolean;
  end;

function TryFoldBinary(const Lhs, Rhs: TMirOperand; Op: TMirOp;
  out OutVal: TMirOperand): Boolean;
var
  L, R, Val: Int64;
  UL, UR, UVal: QWord;
  Cmp: Boolean;
begin
  TryFoldBinary := False;
  if (Lhs.Kind <> mokConst) or (Rhs.Kind <> mokConst) then Exit;
  L := Lhs.ConstVal.IntVal; R := Rhs.ConstVal.IntVal;
  UL := QWord(L); UR := QWord(R);
  case Op of
    moAdd: Val := L + R;
    moSub: Val := L - R;
    moMul: Val := L * R;
    moSDiv: if R <> 0 then Val := L div R else Exit;
    moAnd: Val := L and R;
    moOr:  Val := L or R;
    moXor: Val := L xor R;
    moEq:  Cmp := L = R;
    moNe:  Cmp := L <> R;
    moSLt: Cmp := L < R;
    moSLe: Cmp := L <= R;
    else Exit;
  end;
  OutVal.Kind := mokConst; OutVal.BitWidth := Lhs.BitWidth;
  OutVal.IsSigned := Lhs.IsSigned;
  case Op of
    moEq, moNe, moSLt, moSLe: begin OutVal.ConstVal.IntVal := Ord(Cmp); OutVal.BitWidth := 1; end;
    else OutVal.ConstVal.IntVal := Val;
  end;
  TryFoldBinary := True;
end;

function MakeIntConst(V: Int64): TMirOperand;
begin
  MakeIntConst.Kind := mokConst; MakeIntConst.BitWidth := 64;
  MakeIntConst.IsSigned := True; MakeIntConst.ConstVal.IntVal := V;
end;

var
  A, B, R: TMirOperand;
begin
  A := MakeIntConst(2); B := MakeIntConst(3);
  if not TryFoldBinary(A, B, moAdd, R) then Halt(1);
  if R.ConstVal.IntVal <> 5 then Halt(2);
  if not TryFoldBinary(A, B, moMul, R) then Halt(3);
  if R.ConstVal.IntVal <> 6 then Halt(4);
  A := MakeIntConst(10); B := MakeIntConst(3);
  if not TryFoldBinary(A, B, moSub, R) then Halt(5);
  if R.ConstVal.IntVal <> 7 then Halt(6);
  if not TryFoldBinary(A, B, moSDiv, R) then Halt(7);
  if R.ConstVal.IntVal <> 3 then Halt(8);
  A := MakeIntConst(5); B := MakeIntConst(5);
  if not TryFoldBinary(A, B, moEq, R) then Halt(9);
  if R.ConstVal.IntVal <> 1 then Halt(10);
  A := MakeIntConst(3); B := MakeIntConst(7);
  if not TryFoldBinary(A, B, moSLt, R) then Halt(11);
  if R.ConstVal.IntVal <> 1 then Halt(12);
end.
