program test_mir_dce;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize, nextpas.compiler.ir.mir.pass.dce;

procedure Fail(const AMsg: string);
begin
  WriteLn(StdErr, 'mir-dce-failure=', AMsg);
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

procedure CheckUnusedAssignRemoved;
var
  ModRef: TMirModule;
  Pass: TMirDcePass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
  WasRemoved: Boolean;
begin
  ModRef := TMirModule.Create('test_dce_unused');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');

    { %1 = 42 (never read by any other stmt) }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskAssign;
    Stmt.Dst := 1;
    Stmt.Src := MakeConstInt(42);
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirDcePass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('unused-get-stmt-failed');

    WasRemoved := (Stmt.Dst = 0) or
      ((Stmt.Kind = mskAssign) and (Stmt.Src.Kind = mokConst) and
       (Stmt.Src.ConstVal.IntVal = 0) and (Stmt.Dst = 0));

    if not WasRemoved then
      Fail('unused-assign-not-removed: dst=' + IntToStr(Stmt.Dst) +
        ' kind=' + IntToStr(Ord(Stmt.Kind)));

    WriteLn('mir-dce-unused-removed=ok');
  finally
    ModRef.Free;
  end;
end;

procedure CheckUsedAssignKept;
var
  ModRef: TMirModule;
  Pass: TMirDcePass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_dce_used');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');

    { %1 = 42 }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskAssign;
    Stmt.Dst := 1;
    Stmt.Src := MakeConstInt(42);
    ModRef.AddStmt(FnId, BlkId, Stmt);

    { %2 = %1 + 1 — reads %1, so %1 is live }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 2;
    Stmt.Lhs := MakeLocal(1);
    Stmt.Rhs := MakeConstInt(1);
    Stmt.Op := moAdd;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirDcePass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('used-get-stmt0-failed');
    if Stmt.Dst <> 1 then
      Fail('used-assign-removed');

    WriteLn('mir-dce-used-kept=ok');
  finally
    ModRef.Free;
  end;
end;

procedure CheckChainDeadRemoved;
var
  ModRef: TMirModule;
  Pass: TMirDcePass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_dce_chain');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');

    { %1 = 10 — dead (only read by %2, which is also dead) }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskAssign;
    Stmt.Dst := 1;
    Stmt.Src := MakeConstInt(10);
    ModRef.AddStmt(FnId, BlkId, Stmt);

    { %2 = %1 + 5 — dead (never read) }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 2;
    Stmt.Lhs := MakeLocal(1);
    Stmt.Rhs := MakeConstInt(5);
    Stmt.Op := moAdd;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirDcePass.Create;
    Pass.Run(ModRef);

    { After DCE: %2 is dead → %1 becomes dead → both removed }
    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('chain-get-stmt0-failed');
    if not ModRef.GetStmt(FnId, BlkId, 1, Stmt) then
      Fail('chain-get-stmt1-failed');

    WriteLn('mir-dce-chain-test=ok');
  finally
    ModRef.Free;
  end;
end;

begin
  CheckUnusedAssignRemoved;
  CheckUsedAssignKept;
  CheckChainDeadRemoved;
  WriteLn('mir-dce-status=pass');
end.
