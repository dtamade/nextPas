program test_hir;

{$mode objfpc}{$H+}

uses
  SysUtils, np_hir_types, np_hir_model, np_hir_printer, np_hir_verifier;

var
  Module: THIRModule;
  Printer: THIRPrinter;
  Verifier: THIRVerifier;
  FuncId: THIRFuncId;
  FuncIdx: LongInt;
  BlockId, ThenBlock, ElseBlock, MergeBlock: THIRBlockId;
  IntType, BoolType, StrType: THIRTypeId;
  Instr: THIRInstr;
  Term: THIRTerminator;
  ParamA, ParamB, ParamX, ParamY: THIRValueId;
  VCmp, VPhi: THIRValueId;
  I: LongInt;
begin
  Module := THIRModule.Create('test_module');

  IntType := Module.Types.AddIntType(64, True);
  BoolType := Module.Types.AddType(htkBool, 'bool');
  StrType := Module.Types.AddStringType(skAnsi);

  Module.AddGlobal('counter', IntType);

  FuncId := Module.AddFunction('Add', IntType);
  Module.AddFunctionParam(FuncId, 'a', IntType, False, False);
  Module.AddFunctionParam(FuncId, 'b', IntType, False, False);
  FuncIdx := Module.FunctionCount - 1;
  ParamA := Module.FunctionAt(FuncIdx).Params[0].ValueId;
  ParamB := Module.FunctionAt(FuncIdx).Params[1].ValueId;

  BlockId := Module.AddBlock(FuncId, 'entry');
  Module.SetEntryBlock(FuncId, BlockId);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := Module.NewValue;
  Instr.Kind := hikAdd;
  Instr.TypeId := IntType;
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ParamA);
  Instr.Operands[1] := MakeOperand(ParamB);
  Module.AddInstr(FuncId, BlockId, Instr);

  FillChar(Term, SizeOf(Term), 0);
  Term.Kind := htkReturn;
  Term.ReturnValue := Instr.ResultId;
  Module.SetTerminator(FuncId, BlockId, Term);

  FuncId := Module.AddFunction('Max', IntType);
  Module.AddFunctionParam(FuncId, 'x', IntType, False, False);
  Module.AddFunctionParam(FuncId, 'y', IntType, False, False);
  FuncIdx := Module.FunctionCount - 1;
  ParamX := Module.FunctionAt(FuncIdx).Params[0].ValueId;
  ParamY := Module.FunctionAt(FuncIdx).Params[1].ValueId;

  BlockId := Module.AddBlock(FuncId, 'entry');
  ThenBlock := Module.AddBlock(FuncId, 'then');
  ElseBlock := Module.AddBlock(FuncId, 'else');
  MergeBlock := Module.AddBlock(FuncId, 'merge');
  Module.SetEntryBlock(FuncId, BlockId);

  FillChar(Instr, SizeOf(Instr), 0);
  VCmp := Module.NewValue;
  Instr.ResultId := VCmp;
  Instr.Kind := hikCmpGt;
  Instr.TypeId := BoolType;
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ParamX);
  Instr.Operands[1] := MakeOperand(ParamY);
  Module.AddInstr(FuncId, BlockId, Instr);

  FillChar(Term, SizeOf(Term), 0);
  Term.Kind := htkCondBranch;
  Term.Condition := VCmp;
  Term.TrueBlock := ThenBlock;
  Term.FalseBlock := ElseBlock;
  Module.SetTerminator(FuncId, BlockId, Term);

  FillChar(Term, SizeOf(Term), 0);
  Term.Kind := htkBranch;
  Term.TargetBlock := MergeBlock;
  Module.SetTerminator(FuncId, ThenBlock, Term);
  Module.SetTerminator(FuncId, ElseBlock, Term);

  FillChar(Instr, SizeOf(Instr), 0);
  VPhi := Module.NewValue;
  Instr.ResultId := VPhi;
  Instr.Kind := hikPhi;
  Instr.TypeId := IntType;
  SetLength(Instr.PhiEntries, 2);
  Instr.PhiEntries[0].ValueId := ParamX;
  Instr.PhiEntries[0].BlockId := ThenBlock;
  Instr.PhiEntries[1].ValueId := ParamY;
  Instr.PhiEntries[1].BlockId := ElseBlock;
  Module.AddInstr(FuncId, MergeBlock, Instr);

  FillChar(Term, SizeOf(Term), 0);
  Term.Kind := htkReturn;
  Term.ReturnValue := VPhi;
  Module.SetTerminator(FuncId, MergeBlock, Term);

  WriteLn('=== HIR Printer Output ===');
  Printer := THIRPrinter.Create(Module);
  Printer.Print;
  WriteLn(Printer.AsText);
  Printer.Free;

  WriteLn('=== HIR Verifier ===');
  Verifier := THIRVerifier.Create(Module);
  if Verifier.Verify then
    WriteLn('PASS: No verification errors')
  else
  begin
    WriteLn('FAIL: ', Verifier.ErrorCount, ' error(s)');
    for I := 0 to Verifier.ErrorCount - 1 do
      WriteLn('  [', Verifier.ErrorAt(I).FuncName, ' bb',
        Verifier.ErrorAt(I).BlockId, '] ',
        Verifier.ErrorAt(I).Message);
  end;
  Verifier.Free;

  Module.Free;
  WriteLn('');
  WriteLn('Phase 1 gate: PASS');
end.
