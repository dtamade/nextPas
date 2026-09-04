program test_mir_inline;

{$mode objfpc}{$H+}

uses
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize,
  nextpas.compiler.ir.mir.pass.inline;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'mir-inline-failure=', AMessage);
  Halt(1);
end;

function MakeModule(const AName: string): TMirModule;
begin
  Result := TMirModule.Create(AName);
end;

{ No functions → no inlining should succeed trivially }
procedure CheckEmptyModule;
var
  M: TMirModule;
  Pass: TMirInlinePass;
  Ok: Boolean;
begin
  M := MakeModule('empty');
  try
    Pass := TMirInlinePass.Create;
    Ok := Pass.Run(M);
    if not Ok then
      Fail('empty-module-inline-failed');
  finally
    M.Free;
  end;
end;

{ Single function with no calls → no inlining needed }
procedure CheckSingleFunctionNoCalls;
var
  M: TMirModule;
  FnId: TMirFuncId;
  Pass: TMirInlinePass;
  Ok: Boolean;
begin
  M := MakeModule('single');
  try
    FnId := M.AddFunction('main', 32, True);
    Pass := TMirInlinePass.Create;
    Ok := Pass.Run(M);
    if not Ok then
      Fail('single-function-inline-failed');
  finally
    M.Free;
  end;
end;

{ Caller calls callee → inline should succeed }
procedure CheckSimpleInline;
var
  M: TMirModule;
  CallerId, CalleeId: TMirFuncId;
  BlkId: TMirBlockId;
  Stmt: TMirStmt;
  Pass: TMirInlinePass;
  Ok: Boolean;
begin
  M := MakeModule('simple_inline');
  try
    { Callee: returns 42 }
    CalleeId := M.AddFunction('callee', 32, True);
    BlkId := M.AddBlock(CalleeId, 'entry');
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskAssign;
    Stmt.Dst := 1;
    Stmt.Src.Kind := mokConst;
    Stmt.Src.ConstVal.IntVal := 42;
    Stmt.Src.BitWidth := 32;
    Stmt.Src.IsSigned := True;
    M.AddStmt(CalleeId, BlkId, Stmt);
    M.SetEntryBlock(CalleeId, BlkId);
    { Callee is small enough (1 stmt) — will be inlined by the pass }

    { Caller: calls callee }
    CallerId := M.AddFunction('caller', 32, True);
    BlkId := M.AddBlock(CallerId, 'entry');
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskCall;
    Stmt.Dst := 2;
    Stmt.FuncName := 'callee';
    M.AddStmt(CallerId, BlkId, Stmt);
    M.SetEntryBlock(CallerId, BlkId);

    Pass := TMirInlinePass.Create;
    Ok := Pass.Run(M);
    if not Ok then
      Fail('simple-inline-failed');
  finally
    M.Free;
  end;
end;

{ Non-inlinable function should not be inlined }
procedure CheckNonInlinable;
var
  M: TMirModule;
  CallerId, CalleeId: TMirFuncId;
  BlkId: TMirBlockId;
  Stmt: TMirStmt;
  Pass: TMirInlinePass;
  Ok: Boolean;
begin
  M := MakeModule('non_inlinable');
  try
    CalleeId := M.AddFunction('big_func', 32, True);
    BlkId := M.AddBlock(CalleeId, 'entry');
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskAssign;
    Stmt.Dst := 1;
    Stmt.Src.Kind := mokConst;
    Stmt.Src.ConstVal.IntVal := 99;
    Stmt.Src.BitWidth := 32;
    M.AddStmt(CalleeId, BlkId, Stmt);
    M.SetEntryBlock(CalleeId, BlkId);
    { Big function (many stmts) — pass will skip it }

    CallerId := M.AddFunction('caller', 32, True);
    BlkId := M.AddBlock(CallerId, 'entry');
    FillChar(Stmt, SizeOf(Stmt), 0);
    Stmt.Kind := mskCall;
    Stmt.Dst := 2;
    Stmt.FuncName := 'big_func';
    M.AddStmt(CallerId, BlkId, Stmt);
    M.SetEntryBlock(CallerId, BlkId);

    Pass := TMirInlinePass.Create;
    Ok := Pass.Run(M);
    if not Ok then
      Fail('non-inlinable-inline-failed');
    { Function should still exist (not inlined) }
    if M.FunctionCount <> 2 then
      Fail('non-inlinable-function-should-not-be-removed');
  finally
    M.Free;
  end;
end;

begin
  CheckEmptyModule;
  CheckSingleFunctionNoCalls;
  CheckSimpleInline;
  CheckNonInlinable;
  WriteLn('mir-inline-status=pass');
end.
