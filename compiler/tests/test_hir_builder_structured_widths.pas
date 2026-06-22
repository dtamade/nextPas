program test_hir_builder_structured_widths;

{$mode objfpc}{$H+}

uses
  np_hir_builder,
  np_hir_llvm_emitter,
  np_hir_model,
  np_hir_types,
  np_semantic_model;

var
  Model: TSemanticModel;

function AddTypeWithFact(const AName: string; const AKind: TSemanticScalarKind;
  const ABitWidth: LongInt; const ASigned: Boolean): LongInt;
begin
  Result := Model.AddType(AName, 'builtin');
  Model.SetTypeScalarFact(Result, AKind, ABitWidth, ASigned);
end;

function AddIntLiteral(const AValue: Int64; const ATypeId: LongInt): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 0);
  Result := Model.AddHirExpr(
    shekIntLiteral, ATypeId, 0, Children, AValue, '', '', 0, shvcScalar
  );
end;

function AddSymbolValue(const ASymbolId, ATypeId: LongInt): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 0);
  Result := Model.AddHirExpr(
    shekSymbolValue, ATypeId, ASymbolId, Children, 0, '', '', 0, shvcScalar
  );
end;

function AddCompareOp(const AOp: string; const ALeft, ARight: LongInt;
  const ATypeId: LongInt): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 2);
  Children[0] := ALeft;
  Children[1] := ARight;
  Result := Model.AddHirExpr(
    shekCompareOp, ATypeId, 0, Children, 0, '', AOp, 0, shvcScalar
  );
end;

function AddBinaryOp(const AOp: string; const ALeft, ARight: LongInt;
  const ATypeId: LongInt): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 2);
  Children[0] := ALeft;
  Children[1] := ARight;
  Result := Model.AddHirExpr(
    shekBinaryOp, ATypeId, 0, Children, 0, '', AOp, 0, shvcScalar
  );
end;

function TypeIsIntWidth(const AModule: THIRModule; const ATypeId: THIRTypeId;
  const ABitWidth: Byte; const ASigned: Boolean): Boolean;
var
  TypeRec: THIRTypeRec;
begin
  TypeRec := AModule.Types.GetType(ATypeId);
  Result := (TypeRec.Kind = htkInt) and (TypeRec.BitWidth = ABitWidth) and
    (TypeRec.Signed = ASigned);
end;

function TypeIsBool(const AModule: THIRModule;
  const ATypeId: THIRTypeId): Boolean;
begin
  Result := AModule.Types.GetType(ATypeId).Kind = htkBool;
end;

function FindFunction(const AModule: THIRModule; const AName: string;
  out AFunc: THIRFunction): Boolean;
var
  I: LongInt;
begin
  for I := 0 to AModule.FunctionCount - 1 do
  begin
    AFunc := AModule.FunctionAt(I);
    if AFunc.Name = AName then
      Exit(True);
  end;
  Result := False;
end;

function HasAllocaWidth(const AModule: THIRModule; const AFunc: THIRFunction;
  const ABitWidth: Byte; const ASigned: Boolean): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
      if (AFunc.Blocks[BlockIndex].Instrs[InstrIndex].Kind = hikAlloca) and
        TypeIsIntWidth(AModule,
          AFunc.Blocks[BlockIndex].Instrs[InstrIndex].TypeId,
          ABitWidth, ASigned) then
        Exit(True);
  Result := False;
end;

function HasStoreWidth(const AModule: THIRModule; const AFunc: THIRFunction;
  const ABitWidth: Byte; const ASigned: Boolean): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
      if (AFunc.Blocks[BlockIndex].Instrs[InstrIndex].Kind = hikStore) and
        TypeIsIntWidth(AModule,
          AFunc.Blocks[BlockIndex].Instrs[InstrIndex].TypeId,
          ABitWidth, ASigned) then
        Exit(True);
  Result := False;
end;

function HasBoolAlloca(const AModule: THIRModule;
  const AFunc: THIRFunction): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
      if (AFunc.Blocks[BlockIndex].Instrs[InstrIndex].Kind = hikAlloca) and
        TypeIsBool(AModule,
          AFunc.Blocks[BlockIndex].Instrs[InstrIndex].TypeId) then
        Exit(True);
  Result := False;
end;

function HasByteCompare(const AModule: THIRModule;
  const AFunc: THIRFunction): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
  Instr: THIRInstr;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
    begin
      Instr := AFunc.Blocks[BlockIndex].Instrs[InstrIndex];
      if (Instr.Kind = hikCmpEq) and (Length(Instr.Operands) >= 2) and
        TypeIsBool(AModule, Instr.TypeId) and
        TypeIsIntWidth(AModule, Instr.Operands[0].TypeId, 8, False) and
        TypeIsIntWidth(AModule, Instr.Operands[1].TypeId, 8, False) then
        Exit(True);
    end;
  Result := False;
end;

function HasI32Zext(const AModule: THIRModule;
  const AFunc: THIRFunction): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
  Instr: THIRInstr;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
    begin
      Instr := AFunc.Blocks[BlockIndex].Instrs[InstrIndex];
      if (Instr.Kind = hikZext) and
        TypeIsIntWidth(AModule, Instr.TypeId, 32, True) and
        (Length(Instr.Operands) >= 1) and
        TypeIsBool(AModule, Instr.Operands[0].TypeId) then
        Exit(True);
    end;
  Result := False;
end;

var
  BoolTypeId, ByteTypeId, IntegerTypeId: LongInt;
  SymB, SymI, SymFlag: LongInt;
  ExprByte7, ExprByte0, ExprSymB, ExprCmpEq, ExprCmpNe, ExprAnd: LongInt;
  ExprInt1000: LongInt;
  NodeId: LongInt;
  Builder: THIRBuilder;
  Func: THIRFunction;
  Emitter: THIRLlvmEmitter;
  IR: string;
begin
  Model := TSemanticModel.Create;
  try
    BoolTypeId := AddTypeWithFact('Boolean', sskBool, 1, False);
    ByteTypeId := AddTypeWithFact('Byte', sskInt, 8, False);
    IntegerTypeId := AddTypeWithFact('Integer', sskInt, 32, True);

    SymB := Model.AddSymbol('b', 'variable', '', ByteTypeId, 0);
    SymI := Model.AddSymbol('i', 'variable', '', IntegerTypeId, 0);
    SymFlag := Model.AddSymbol('flag', 'variable', '', BoolTypeId, 0);

    ExprByte7 := AddIntLiteral(7, ByteTypeId);
    ExprByte0 := AddIntLiteral(0, ByteTypeId);
    ExprSymB := AddSymbolValue(SymB, ByteTypeId);
    ExprCmpEq := AddCompareOp('=', ExprSymB, ExprByte7, BoolTypeId);
    ExprCmpNe := AddCompareOp('<>', ExprSymB, ExprByte0, BoolTypeId);
    ExprAnd := AddBinaryOp('and', ExprCmpEq, ExprCmpNe, BoolTypeId);
    ExprInt1000 := AddIntLiteral(1000, IntegerTypeId);

    Model.AddTypedHirNode('function-body-begin', 'TestWidths', 0,
      IntegerTypeId, '0::i');

    Model.AddTypedHirNode('var-decl-runtime', 'b', SymB, ByteTypeId, 'b');
    NodeId := Model.AddTypedHirNode('assign-runtime', 'b := 7',
      SymB, ByteTypeId, 'b'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprByte7);

    Model.AddTypedHirNode('var-decl-runtime', 'i', SymI, IntegerTypeId, 'i');
    NodeId := Model.AddTypedHirNode('assign-runtime', 'i := 1000',
      SymI, IntegerTypeId, 'i'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprInt1000);

    Model.AddTypedHirNode('var-decl-runtime', 'flag', SymFlag,
      BoolTypeId, 'flag');
    NodeId := Model.AddTypedHirNode('assign-runtime', 'flag := b = 7',
      SymFlag, BoolTypeId, 'flag'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprCmpEq);
    NodeId := Model.AddTypedHirNode('assign-runtime', 'flag := cmp and cmp',
      SymFlag, BoolTypeId, 'flag'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprAnd);

    Model.AddTypedHirNode('function-body-end', 'TestWidths', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      if not FindFunction(Builder.Module, 'TestWidths', Func) then
        Halt(1);
      if not HasAllocaWidth(Builder.Module, Func, 8, False) then
        Halt(2);
      if not HasStoreWidth(Builder.Module, Func, 8, False) then
        Halt(3);
      if not HasAllocaWidth(Builder.Module, Func, 32, True) then
        Halt(4);
      if not HasStoreWidth(Builder.Module, Func, 32, True) then
        Halt(5);
      if not HasBoolAlloca(Builder.Module, Func) then
        Halt(6);
      if not HasByteCompare(Builder.Module, Func) then
        Halt(7);
      if not HasI32Zext(Builder.Module, Func) then
        Halt(8);

      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        IR := Emitter.AsText;
        if Pos('icmp eq i8 ', IR) = 0 then
          Halt(9);
        if Pos('zext i1 ', IR) = 0 then
          Halt(10);
        if Pos(' to i32', IR) = 0 then
          Halt(11);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;
end.
