program test_hir_dynarray_typed_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.diagnostics.sink,
  nextpas.compiler.syntax.green_tree,
  np_hir_builder,
  np_hir_llvm_emitter,
  np_hir_model,
  np_hir_types,
  nextpas.compiler.syntax.lexer,
  np_semantic_analyzer,
  np_semantic_model,
  np_system_contracts,
  nextpas.compiler.frontend.unit_graph;

const
  LocalOwnedSource =
    'program test;' + LineEnding +
    'procedure Touch;' + LineEnding +
    'var Local: array of Integer;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(Local, 4);' + LineEnding +
    '  if Length(Local) = 0 then Exit;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  FieldOwnedSource =
    'program test;' + LineEnding +
    'type TBox = class' + LineEnding +
    '  Items: array of Integer;' + LineEnding +
    '  procedure Resize;' + LineEnding +
    'end;' + LineEnding +
    'procedure TBox.Resize;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(Items, 2);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-dynarray-typed-contract-failure=', AMessage);
  Halt(1);
end;

function BuildModel(const ASource: string): TSemanticModel;
var
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Tree: TGreenTree;
  Ast: TAstFacade;
  Graph: TUnitGraph;
  Analyzer: TSemanticAnalyzer;
begin
  Result := nil;
  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := nil;
  Tree := nil;
  Ast := nil;
  Graph := nil;
  Analyzer := nil;
  try
    Lexer := TLexerResult.Create(ASource, Diagnostics, 1);
    Tree := ParseGreenTree(Lexer, Diagnostics, 1);
    Ast := TAstFacade.Create(Tree);
    Graph := TUnitGraph.Create;
    Graph.SetRootName('test');
    Graph.MarkReady;
    Analyzer := TSemanticAnalyzer.Create(Ast, Graph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Result := Analyzer.DetachModel;
  finally
    Analyzer.Free;
    Graph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end;

procedure AssertTypedDynArrayContracts(const ASource: string;
  const ALabel: string; ARequireSetLength, ARequireFini: Boolean);
var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  Func: THIRFunction;
  Instr: THIRInstr;
  ContractDefinition: TSystemContractDefinition;
  OperandType: THIRTypeRec;
  FuncIndex, BlockIndex, InstrIndex, OperandIndex: LongInt;
  SetLengthCount, FiniCount: LongInt;
  LlvmText: string;
begin
  Model := BuildModel(ASource);
  Builder := nil;
  Emitter := nil;
  try
    if Model = nil then
      Fail(ALabel + '-model-nil');
    Builder := THIRBuilder.Create(Model);
    Builder.Build;
    SetLengthCount := 0;
    FiniCount := 0;
    for FuncIndex := 0 to Builder.Module.FunctionCount - 1 do
    begin
      Func := Builder.Module.FunctionAt(FuncIndex);
      if Func.Blocks = nil then
        Continue;
      for BlockIndex := 0 to LongInt(Func.Blocks.Count) - 1 do
        if Func.Blocks[SizeUInt(BlockIndex)].Instrs <> nil then
          for InstrIndex := 0 to
            LongInt(Func.Blocks[SizeUInt(BlockIndex)].Instrs.Count) - 1 do
          begin
            Instr := Func.Blocks[SizeUInt(BlockIndex)].Instrs[
              SizeUInt(InstrIndex)];
            if (Instr.Kind = hikIntrinsic) and
              IsSystemContract(Instr, sckDynArraySetLength) then
            begin
              Inc(SetLengthCount);
              ContractDefinition := SystemContractAt(sckDynArraySetLength);
              if Instr.IntrinsicName <> ContractDefinition.SemanticName then
                Fail(ALabel + '-setlength-name-mismatch:' + Instr.IntrinsicName);
              if Instr.CallTarget <> ContractDefinition.RuntimeMapping then
                Fail(ALabel + '-setlength-runtime-mismatch:' + Instr.CallTarget);
              if Length(Instr.Operands) <> 4 then
                Fail(ALabel + '-setlength-operand-count:' +
                  IntToStr(Length(Instr.Operands)));
              OperandType := Builder.Module.Types.GetType(
                Instr.Operands[0].TypeId);
              if OperandType.Kind <> htkPointer then
                Fail(ALabel + '-setlength-operand0-not-pointer');
              for OperandIndex := 1 to High(Instr.Operands) do
              begin
                OperandType := Builder.Module.Types.GetType(
                  Instr.Operands[OperandIndex].TypeId);
                if OperandType.Kind <> htkInt then
                  Fail(ALabel + '-setlength-operand-not-int:' +
                    IntToStr(OperandIndex));
              end;
            end;
            if (Instr.Kind = hikIntrinsic) and
              IsSystemContract(Instr, sckDynArrayFini) then
            begin
              Inc(FiniCount);
              ContractDefinition := SystemContractAt(sckDynArrayFini);
              if Instr.IntrinsicName <> ContractDefinition.SemanticName then
                Fail(ALabel + '-fini-name-mismatch:' + Instr.IntrinsicName);
              if Instr.CallTarget <> ContractDefinition.RuntimeMapping then
                Fail(ALabel + '-fini-runtime-mismatch:' + Instr.CallTarget);
              if Length(Instr.Operands) <> 3 then
                Fail(ALabel + '-fini-operand-count:' +
                  IntToStr(Length(Instr.Operands)));
              OperandType := Builder.Module.Types.GetType(
                Instr.Operands[0].TypeId);
              if OperandType.Kind <> htkPointer then
                Fail(ALabel + '-fini-operand0-not-pointer');
              for OperandIndex := 1 to High(Instr.Operands) do
              begin
                OperandType := Builder.Module.Types.GetType(
                  Instr.Operands[OperandIndex].TypeId);
                if OperandType.Kind <> htkInt then
                  Fail(ALabel + '-fini-operand-not-int:' +
                    IntToStr(OperandIndex));
              end;
            end;
            { Legacy bare names must not remain as untyped authority. }
            if (Instr.Kind = hikIntrinsic) and (not Instr.HasSystemContract) and
              ((Instr.IntrinsicName = 'dynarray_resize') or
              (Instr.IntrinsicName = 'dynarray_release')) then
              Fail(ALabel + '-legacy-untyped-dynarray-intrinsic:' +
                Instr.IntrinsicName);
          end;
    end;
    if ARequireSetLength and (SetLengthCount = 0) then
      Fail(ALabel + '-missing-typed-setlength');
    if ARequireFini and (FiniCount = 0) then
      Fail(ALabel + '-missing-typed-fini');

    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;
    if ARequireSetLength and
      (Pos('call ptr @np_dynarray_resize(', LlvmText) = 0) then
      Fail(ALabel + '-missing-llvm-resize-call');
    if ARequireFini and
      (Pos('call void @np_dynarray_release(', LlvmText) = 0) then
      Fail(ALabel + '-missing-llvm-release-call');
    if Pos('declare ptr @np_dynarray_resize(', LlvmText) = 0 then
      Fail(ALabel + '-missing-resize-declare');
    if Pos('declare void @np_dynarray_release(', LlvmText) = 0 then
      Fail(ALabel + '-missing-release-declare');
  finally
    Emitter.Free;
    Builder.Free;
    Model.Free;
  end;
end;

begin
  AssertTypedDynArrayContracts(LocalOwnedSource, 'local', True, True);
  AssertTypedDynArrayContracts(FieldOwnedSource, 'field', True, False);
  WriteLn('hir-dynarray-typed-contract-status=pass');
end.