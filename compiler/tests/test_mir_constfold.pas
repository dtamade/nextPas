program test_mir_constfold;

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize, nextpas.compiler.ir.mir.pass.constfold;

procedure Fail(const AMsg: string);
begin
  WriteLn(StdErr, 'mir-constfold-failure=', AMsg);
  Halt(1);
end;

function MakeConstInt(AVal: Int64; ABitWidth: LongInt = 32): TMirOperand;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := mokConst;
  Result.BitWidth := ABitWidth;
  Result.ConstVal.IntVal := AVal;
end;

function MakeLocal(AVal: TMirValueId; ABitWidth: LongInt = 32): TMirOperand;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := mokLocal;
  Result.Value := AVal;
  Result.BitWidth := ABitWidth;
end;

procedure CheckAddFold;
var
  ModRef: TMirModule;
  Pass: TMirConstFoldPass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_add');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeConstInt(2);
    Stmt.Rhs := MakeConstInt(3);
    Stmt.Op := moAdd;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirConstFoldPass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('add-get-stmt-failed');
    if Stmt.Kind <> mskAssign then
      Fail('add-not-folded-to-assign');
    if Stmt.Src.Kind <> mokConst then
      Fail('add-src-not-const');
    if Stmt.Src.ConstVal.IntVal <> 5 then
      Fail('add-result-not-5:' + IntToStr(Stmt.Src.ConstVal.IntVal));

    // Pass freed by interface refcount
  finally
    ModRef.Free;
  end;
end;

procedure CheckSubFold;
var
  ModRef: TMirModule;
  Pass: TMirConstFoldPass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_sub');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeConstInt(10);
    Stmt.Rhs := MakeConstInt(3);
    Stmt.Op := moSub;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirConstFoldPass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('sub-get-stmt-failed');
    if Stmt.Kind <> mskAssign then
      Fail('sub-not-folded');
    if Stmt.Src.ConstVal.IntVal <> 7 then
      Fail('sub-result-not-7:' + IntToStr(Stmt.Src.ConstVal.IntVal));

    // Pass freed by interface refcount
  finally
    ModRef.Free;
  end;
end;

procedure CheckMulFold;
var
  ModRef: TMirModule;
  Pass: TMirConstFoldPass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_mul');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeConstInt(4);
    Stmt.Rhs := MakeConstInt(7);
    Stmt.Op := moMul;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirConstFoldPass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('mul-get-stmt-failed');
    if Stmt.Kind <> mskAssign then
      Fail('mul-not-folded');
    if Stmt.Src.ConstVal.IntVal <> 28 then
      Fail('mul-result-not-28:' + IntToStr(Stmt.Src.ConstVal.IntVal));

    // Pass freed by interface refcount
  finally
    ModRef.Free;
  end;
end;

procedure CheckDivByZeroNoFold;
var
  ModRef: TMirModule;
  Pass: TMirConstFoldPass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_div0');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeConstInt(10);
    Stmt.Rhs := MakeConstInt(0);
    Stmt.Op := moSDiv;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirConstFoldPass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('div0-get-stmt-failed');
    if Stmt.Kind = mskAssign then
      Fail('div0-should-not-fold');

    // Pass freed by interface refcount
  finally
    ModRef.Free;
  end;
end;

procedure CheckNonConstNoFold;
var
  ModRef: TMirModule;
  Pass: TMirConstFoldPass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_nonconst');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeLocal(10);
    Stmt.Rhs := MakeConstInt(5);
    Stmt.Op := moAdd;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirConstFoldPass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('nonconst-get-stmt-failed');
    if Stmt.Kind = mskAssign then
      Fail('nonconst-should-not-fold');

    // Pass freed by interface refcount
  finally
    ModRef.Free;
  end;
end;

procedure CheckNegFold;
var
  ModRef: TMirModule;
  Pass: TMirConstFoldPass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_neg');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskUnary;
    Stmt.Dst := 1;
    Stmt.Src := MakeConstInt(42);
    Stmt.Op := moNeg;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirConstFoldPass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('neg-get-stmt-failed');
    if Stmt.Kind <> mskAssign then
      Fail('neg-not-folded');
    if Stmt.Src.ConstVal.IntVal <> -42 then
      Fail('neg-result-not--42:' + IntToStr(Stmt.Src.ConstVal.IntVal));

    // Pass freed by interface refcount
  finally
    ModRef.Free;
  end;
end;

procedure CheckBitwiseFold;
var
  ModRef: TMirModule;
  Pass: TMirConstFoldPass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_bitwise');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');

    { AND: 0xFF AND 0x0F = 0x0F }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeConstInt($FF);
    Stmt.Rhs := MakeConstInt($0F);
    Stmt.Op := moAnd;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirConstFoldPass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('and-get-stmt-failed');
    if Stmt.Kind <> mskAssign then
      Fail('and-not-folded');
    if Stmt.Src.ConstVal.IntVal <> $0F then
      Fail('and-result-not-0F:' + IntToStr(Stmt.Src.ConstVal.IntVal));

    // Pass freed by interface refcount
  finally
    ModRef.Free;
  end;
end;

procedure CheckComparisonFold;
var
  ModRef: TMirModule;
  Pass: TMirConstFoldPass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_cmp');
  try
    FnId := ModRef.AddFunction('test', 1, False);
    BlkId := ModRef.AddBlock(FnId, 'entry');

    { 5 < 10 = true }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeConstInt(5);
    Stmt.Rhs := MakeConstInt(10);
    Stmt.Op := moSLt;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirConstFoldPass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('cmp-get-stmt-failed');
    if Stmt.Kind <> mskAssign then
      Fail('cmp-not-folded');
    if Stmt.Src.ConstVal.IntVal <> 1 then
      Fail('cmp-result-not-1:' + IntToStr(Stmt.Src.ConstVal.IntVal));

    // Pass freed by interface refcount
  finally
    ModRef.Free;
  end;
end;

procedure CheckPassManagerRunsAll;
var
  ModRef: TMirModule;
  PM: TMirPassManager;
  Pass1, Pass2: TMirConstFoldPass;
  FnId, BlkId: TMirFuncId;
  Stmt: TMirStmt;
begin
  ModRef := TMirModule.Create('test_pm');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeConstInt(3);
    Stmt.Rhs := MakeConstInt(4);
    Stmt.Op := moAdd;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    PM := TMirPassManager.Create;
    Pass1 := TMirConstFoldPass.Create;
    Pass2 := TMirConstFoldPass.Create;
    try
      PM.RegisterPass(Pass1);
      PM.RegisterPass(Pass2);

      if PM.PassCount <> 2 then
        Fail('pm-count-not-2');

      if not PM.RunAll(ModRef) then
        Fail('pm-run-failed');

      if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
        Fail('pm-get-stmt-failed');
      if Stmt.Kind <> mskAssign then
        Fail('pm-fold-not-applied');
    finally
      // Pass2 freed by interface refcount
      // Pass1 freed by interface refcount
      PM.Free;
    end;
  finally
    ModRef.Free;
  end;
end;

begin
  CheckAddFold;
  CheckSubFold;
  CheckMulFold;
  CheckDivByZeroNoFold;
  CheckNonConstNoFold;
  CheckNegFold;
  CheckBitwiseFold;
  CheckComparisonFold;
  CheckPassManagerRunsAll;
  WriteLn('mir-constfold-status=pass');
end.
