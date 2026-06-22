program test_hir_builder_structured_casts;

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

function AddCastExpr(const AChild, ATargetTypeId: LongInt): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 1);
  Children[0] := AChild;
  Result := Model.AddHirExpr(
    shekCast, ATargetTypeId, 0, Children, 0, '', '', 0, shvcScalar
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

function HasCastInstr(const AModule: THIRModule; const AFunc: THIRFunction;
  const AKind: THIRInstrKind; const AResultBitWidth: Byte;
  const AResultSigned: Boolean; const AOperandBitWidth: Byte;
  const AOperandSigned: Boolean): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
  Instr: THIRInstr;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
    begin
      Instr := AFunc.Blocks[BlockIndex].Instrs[InstrIndex];
      if (Instr.Kind = AKind) and
        TypeIsIntWidth(AModule, Instr.TypeId, AResultBitWidth, AResultSigned) and
        (Length(Instr.Operands) >= 1) and
        TypeIsIntWidth(AModule, Instr.Operands[0].TypeId, AOperandBitWidth,
          AOperandSigned) then
        Exit(True);
    end;
  Result := False;
end;

var
  ByteTypeId, ShortIntTypeId, IntegerTypeId: LongInt;
  SymByte, SymShortInt, SymInt, SymWideUnsigned, SymWideSigned, SymNarrow: LongInt;
  ExprByte7, ExprShortIntNeg3, ExprInt1000: LongInt;
  ExprByteToInt, ExprShortIntToInt, ExprIntToByte: LongInt;
  ExprUnsignedAdd, ExprSignedAdd: LongInt;
  NodeId: LongInt;
  Builder: THIRBuilder;
  Func: THIRFunction;
  Emitter: THIRLlvmEmitter;
  IR: string;
begin
  Model := TSemanticModel.Create;
  try
    ByteTypeId := AddTypeWithFact('Byte', sskInt, 8, False);
    ShortIntTypeId := AddTypeWithFact('ShortInt', sskInt, 8, True);
    IntegerTypeId := AddTypeWithFact('Integer', sskInt, 32, True);

    SymByte := Model.AddSymbol('b', 'variable', '', ByteTypeId, 0);
    SymShortInt := Model.AddSymbol('s', 'variable', '', ShortIntTypeId, 0);
    SymInt := Model.AddSymbol('i', 'variable', '', IntegerTypeId, 0);
    SymWideUnsigned := Model.AddSymbol('wideUnsigned', 'variable', '',
      IntegerTypeId, 0);
    SymWideSigned := Model.AddSymbol('wideSigned', 'variable', '',
      IntegerTypeId, 0);
    SymNarrow := Model.AddSymbol('narrow', 'variable', '', ByteTypeId, 0);

    ExprByte7 := AddIntLiteral(7, ByteTypeId);
    ExprShortIntNeg3 := AddIntLiteral(-3, ShortIntTypeId);
    ExprInt1000 := AddIntLiteral(1000, IntegerTypeId);

    ExprByteToInt := AddCastExpr(AddSymbolValue(SymByte, ByteTypeId),
      IntegerTypeId);
    ExprShortIntToInt := AddCastExpr(AddSymbolValue(SymShortInt, ShortIntTypeId),
      IntegerTypeId);
    ExprIntToByte := AddCastExpr(AddSymbolValue(SymInt, IntegerTypeId),
      ByteTypeId);

    ExprUnsignedAdd := AddBinaryOp('+', ExprByteToInt, ExprInt1000,
      IntegerTypeId);
    ExprSignedAdd := AddBinaryOp('+', ExprShortIntToInt, ExprInt1000,
      IntegerTypeId);

    Model.AddTypedHirNode('function-body-begin', 'TestStructuredCasts', 0,
      IntegerTypeId, '0::i');

    Model.AddTypedHirNode('var-decl-runtime', 'b', SymByte, ByteTypeId, 'b');
    NodeId := Model.AddTypedHirNode('assign-runtime', 'b := 7',
      SymByte, ByteTypeId, 'b'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprByte7);

    Model.AddTypedHirNode('var-decl-runtime', 's', SymShortInt,
      ShortIntTypeId, 's');
    NodeId := Model.AddTypedHirNode('assign-runtime', 's := -3',
      SymShortInt, ShortIntTypeId, 's'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprShortIntNeg3);

    Model.AddTypedHirNode('var-decl-runtime', 'i', SymInt, IntegerTypeId, 'i');
    NodeId := Model.AddTypedHirNode('assign-runtime', 'i := 1000',
      SymInt, IntegerTypeId, 'i'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprInt1000);

    Model.AddTypedHirNode('var-decl-runtime', 'wideUnsigned',
      SymWideUnsigned, IntegerTypeId, 'wideUnsigned');
    NodeId := Model.AddTypedHirNode('assign-runtime',
      'wideUnsigned := Integer(b) + 1000', SymWideUnsigned, IntegerTypeId,
      'wideUnsigned'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprUnsignedAdd);

    Model.AddTypedHirNode('var-decl-runtime', 'wideSigned',
      SymWideSigned, IntegerTypeId, 'wideSigned');
    NodeId := Model.AddTypedHirNode('assign-runtime',
      'wideSigned := Integer(s) + 1000', SymWideSigned, IntegerTypeId,
      'wideSigned'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprSignedAdd);

    Model.AddTypedHirNode('var-decl-runtime', 'narrow', SymNarrow,
      ByteTypeId, 'narrow');
    NodeId := Model.AddTypedHirNode('assign-runtime', 'narrow := Byte(i)',
      SymNarrow, ByteTypeId, 'narrow'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprIntToByte);

    Model.AddTypedHirNode('function-body-end', 'TestStructuredCasts', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      if not FindFunction(Builder.Module, 'TestStructuredCasts', Func) then
        Halt(1);
      if not HasCastInstr(Builder.Module, Func, hikZext, 32, True, 8, False) then
        Halt(2);
      if not HasCastInstr(Builder.Module, Func, hikSext, 32, True, 8, True) then
        Halt(3);
      if not HasCastInstr(Builder.Module, Func, hikTrunc, 8, False, 32, True) then
        Halt(4);

      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        IR := Emitter.AsText;
        if Pos('zext i8 ', IR) = 0 then
          Halt(5);
        if Pos('sext i8 ', IR) = 0 then
          Halt(6);
        if Pos('trunc i32 ', IR) = 0 then
          Halt(7);
        if Pos(' to i32', IR) = 0 then
          Halt(8);
        if Pos(' to i8', IR) = 0 then
          Halt(9);
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
