program test_mir_deadarg;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize,
  nextpas.compiler.ir.mir.pass.deadarg;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'mir-deadarg-failure=', AMessage);
  Halt(1);
end;

function MakeModule(const AName: string): TMirModule;
begin
  Result := TMirModule.Create(AName);
end;

{ No functions → should succeed trivially }
procedure CheckEmptyModule;
var
  M: TMirModule;
  Pass: TMirDeadArgPass;
  Ok: Boolean;
begin
  M := MakeModule('empty');
  try
    Pass := TMirDeadArgPass.Create;
    Ok := Pass.Run(M);
    if not Ok then
      Fail('empty-module-deadarg-failed');
  finally
    M.Free;
  end;
end;

{ Function with no params → nothing to remove }
procedure CheckNoParams;
var
  M: TMirModule;
  FnId: TMirFuncId;
  BlkId: TMirBlockId;
  Pass: TMirDeadArgPass;
  Ok: Boolean;
begin
  M := MakeModule('no_params');
  try
    FnId := M.AddFunction('f', 32, True);
    BlkId := M.AddBlock(FnId, 'entry');
    M.SetEntryBlock(FnId, BlkId);
    Pass := TMirDeadArgPass.Create;
    Ok := Pass.Run(M);
    if not Ok then
      Fail('no-params-deadarg-failed');
  finally
    M.Free;
  end;
end;

{ Unused parameter should be eliminated }
procedure CheckUnusedParam;
var
  M: TMirModule;
  FnId: TMirFuncId;
  BlkId: TMirBlockId;
  Pass: TMirDeadArgPass;
  Stmt: TMirStmt;
  ParamCount: LongInt;
  Ok: Boolean;
begin
  M := MakeModule('unused_param');
  try
    FnId := M.AddFunction('f', 32, True);
    M.AddParam(FnId, 'used', 32, True);
    M.AddParam(FnId, 'unused', 32, True);
    BlkId := M.AddBlock(FnId, 'entry');
    { Only use the first param }
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskAssign;
    Stmt.Dst := 1;
    Stmt.Src.Kind := mokLocal;
    Stmt.Src.Value := 1;  { first param = value 1 }
    Stmt.Src.BitWidth := 32;
    M.AddStmt(FnId, BlkId, Stmt);
    M.SetEntryBlock(FnId, BlkId);

    Pass := TMirDeadArgPass.Create;
    Ok := Pass.Run(M);
    if not Ok then
      Fail('unused-param-deadarg-failed');
    { Should have eliminated at least 1 param }
    ParamCount := Length(M.FunctionAt(0).Params);
    if ParamCount >= 2 then
      Fail('unused-param-not-eliminated: still ' + IntToStr(ParamCount) + ' params');
  finally
    M.Free;
  end;
end;

{ All params used → nothing to remove }
procedure CheckAllParamsUsed;
var
  M: TMirModule;
  FnId: TMirFuncId;
  BlkId: TMirBlockId;
  Pass: TMirDeadArgPass;
  Stmt: TMirStmt;
  Ok: Boolean;
begin
  M := MakeModule('all_used');
  try
    FnId := M.AddFunction('f', 32, True);
    M.AddParam(FnId, 'a', 32, True);
    M.AddParam(FnId, 'b', 32, True);
    BlkId := M.AddBlock(FnId, 'entry');
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskBinary;
    Stmt.Dst := 1;
    Stmt.Op := moAdd;
    Stmt.Lhs.Kind := mokLocal;
    Stmt.Lhs.Value := 1;  { param a }
    Stmt.Lhs.BitWidth := 32;
    Stmt.Rhs.Kind := mokLocal;
    Stmt.Rhs.Value := 2;  { param b }
    Stmt.Rhs.BitWidth := 32;
    M.AddStmt(FnId, BlkId, Stmt);
    M.SetEntryBlock(FnId, BlkId);

    Pass := TMirDeadArgPass.Create;
    Ok := Pass.Run(M);
    if not Ok then
      Fail('all-params-used-deadarg-failed');
    if Length(M.FunctionAt(0).Params) <> 2 then
      Fail('all-params-should-be-kept');
  finally
    M.Free;
  end;
end;

begin
  CheckEmptyModule;
  CheckNoParams;
  CheckUnusedParam;
  CheckAllParamsUsed;
  WriteLn('mir-deadarg-status=pass');
end.
