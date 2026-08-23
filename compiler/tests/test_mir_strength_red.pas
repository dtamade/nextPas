program test_mir_strength_red;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize, nextpas.compiler.ir.mir.pass.strength_red;

procedure Fail(const AMsg: string);
begin
  WriteLn(StdErr, 'mir-strength-red-failure=', AMsg);
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

procedure CheckMulByPowerOfTwoToShl;
var
  ModRef: TMirModule;
  Pass: TMirStrengthRedPass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_mul2shl');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');

    { %1 = %x * 8 → %1 = %x shl 3 }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeLocal(10);
    Stmt.Rhs := MakeConstInt(8);
    Stmt.Op := moMul;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirStrengthRedPass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('mul2shl-get-stmt-failed');
    if Stmt.Op <> moShl then
      Fail('mul2shl-not-reduced: op=' + IntToStr(Ord(Stmt.Op)));
    if Stmt.Rhs.ConstVal.IntVal <> 3 then
      Fail('mul2shl-wrong-shift:' + IntToStr(Stmt.Rhs.ConstVal.IntVal));

    WriteLn('mir-sr-mul2shl=ok');
  finally
    ModRef.Free;
  end;
end;

procedure CheckMulByNonPowerOfTwoUnchanged;
var
  ModRef: TMirModule;
  Pass: TMirStrengthRedPass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_mul_nonpow2');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');

    { %1 = %x * 7 — 7 is not power of 2, should not reduce }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeLocal(10);
    Stmt.Rhs := MakeConstInt(7);
    Stmt.Op := moMul;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirStrengthRedPass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('mul-nonpow2-get-stmt-failed');
    if Stmt.Op <> moMul then
      Fail('mul-nonpow2-incorrectly-reduced');

    WriteLn('mir-sr-nonpow2-unchanged=ok');
  finally
    ModRef.Free;
  end;
end;

procedure CheckUDivByPowerOfTwoToLShr;
var
  ModRef: TMirModule;
  Pass: TMirStrengthRedPass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_udiv2lshr');
  try
    FnId := ModRef.AddFunction('test', 32, False);
    BlkId := ModRef.AddBlock(FnId, 'entry');

    { %1 = %x / 4 → %1 = %x lshr 2 }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeLocal(10);
    Stmt.Rhs := MakeConstInt(4);
    Stmt.Op := moUDiv;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirStrengthRedPass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('udiv2lshr-get-stmt-failed');
    if Stmt.Op <> moLShr then
      Fail('udiv2lshr-not-reduced');
    if Stmt.Rhs.ConstVal.IntVal <> 2 then
      Fail('udiv2lshr-wrong-shift');

    WriteLn('mir-sr-udiv2lshr=ok');
  finally
    ModRef.Free;
  end;
end;

procedure CheckSDivByPowerOfTwoToAShr;
var
  ModRef: TMirModule;
  Pass: TMirStrengthRedPass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_sdiv2ashr');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');

    { %1 = %x / 2 → %1 = %x ashr 1 }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeLocal(10);
    Stmt.Rhs := MakeConstInt(2);
    Stmt.Op := moSDiv;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirStrengthRedPass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('sdiv2ashr-get-stmt-failed');
    if Stmt.Op <> moAShr then
      Fail('sdiv2ashr-not-reduced');
    if Stmt.Rhs.ConstVal.IntVal <> 1 then
      Fail('sdiv2ashr-wrong-shift');

    WriteLn('mir-sr-sdiv2ashr=ok');
  finally
    ModRef.Free;
  end;
end;

procedure CheckAddNotReduced;
var
  ModRef: TMirModule;
  Pass: TMirStrengthRedPass;
  Stmt: TMirStmt;
  FnId, BlkId: TMirFuncId;
begin
  ModRef := TMirModule.Create('test_add_nored');
  try
    FnId := ModRef.AddFunction('test', 32, True);
    BlkId := ModRef.AddBlock(FnId, 'entry');

    { %1 = %x + %y — addition should never be reduced }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Lhs := MakeLocal(10);
    Stmt.Rhs := MakeLocal(20);
    Stmt.Op := moAdd;
    ModRef.AddStmt(FnId, BlkId, Stmt);

    Pass := TMirStrengthRedPass.Create;
    Pass.Run(ModRef);

    if not ModRef.GetStmt(FnId, BlkId, 0, Stmt) then
      Fail('add-nored-get-stmt-failed');
    if Stmt.Op <> moAdd then
      Fail('add-incorrectly-reduced');

    WriteLn('mir-sr-add-unchanged=ok');
  finally
    ModRef.Free;
  end;
end;

begin
  CheckMulByPowerOfTwoToShl;
  CheckMulByNonPowerOfTwoUnchanged;
  CheckUDivByPowerOfTwoToLShr;
  CheckSDivByPowerOfTwoToAShr;
  CheckAddNotReduced;
  WriteLn('mir-strength-red-status=pass');
end.
