program test_mir_cse;

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize, nextpas.compiler.ir.mir.pass.cse;

procedure Fail(const AMsg: string);
begin
  WriteLn(StdErr, 'mir-cse-failure=', AMsg);
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

procedure CheckDuplicateBinaryEliminated;
var
  ModRef: TMirModule;
  Pass: TMirCsePass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_cse_dup');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');

    { %1 = %a + %b }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeLocal(10);
    Stmt.Rhs := MakeLocal(20);
    Stmt.Op := moAdd;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    { %2 = %a + %b — duplicate, should be replaced with %1 }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 2;
    Stmt.Lhs := MakeLocal(10);
    Stmt.Rhs := MakeLocal(20);
    Stmt.Op := moAdd;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirCsePass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 1, Stmt) then
      Fail('cse-get-stmt1-failed');
    if Stmt.Kind <> mskAssign then
      Fail('cse-dup-not-eliminated: kind=' + IntToStr(Ord(Stmt.Kind)));
    if Stmt.Src.Kind <> mokMove then
      Fail('cse-dup-not-move');
    if Stmt.Src.Value <> 1 then
      Fail('cse-dup-wrong-reg:' + IntToStr(Stmt.Src.Value));

    WriteLn('mir-cse-dup-eliminated=ok');
  finally
    ModRef.Free;
  end;
end;

procedure CheckDifferentOpNotEliminated;
var
  ModRef: TMirModule;
  Pass: TMirCsePass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_cse_diffop');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');

    { %1 = %a + %b }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeLocal(10);
    Stmt.Rhs := MakeLocal(20);
    Stmt.Op := moAdd;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    { %2 = %a - %b — different op, should NOT be eliminated }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 2;
    Stmt.Lhs := MakeLocal(10);
    Stmt.Rhs := MakeLocal(20);
    Stmt.Op := moSub;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirCsePass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 1, Stmt) then
      Fail('cse-diffop-get-stmt1-failed');
    if Stmt.Kind = mskAssign then
      Fail('cse-diffop-incorrectly-eliminated');

    WriteLn('mir-cse-diffop-kept=ok');
  finally
    ModRef.Free;
  end;
end;

procedure CheckFirstOccurrenceKept;
var
  ModRef: TMirModule;
  Pass: TMirCsePass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_cse_first');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');

    { %1 = %a * %b — first occurrence, should be kept as-is }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeLocal(10);
    Stmt.Rhs := MakeLocal(20);
    Stmt.Op := moMul;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirCsePass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('cse-first-get-stmt-failed');
    if Stmt.Kind <> mskBinary then
      Fail('cse-first-incorrectly-modified');
    if Stmt.Op <> moMul then
      Fail('cse-first-op-changed');

    WriteLn('mir-cse-first-kept=ok');
  finally
    ModRef.Free;
  end;
end;

begin
  CheckDuplicateBinaryEliminated;
  CheckDifferentOpNotEliminated;
  CheckFirstOccurrenceKept;
  WriteLn('mir-cse-status=pass');
end.
