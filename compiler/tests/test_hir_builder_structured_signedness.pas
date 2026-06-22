program test_hir_builder_structured_signedness;

{$mode objfpc}{$H+}

uses
  np_hir_builder,
  np_hir_llvm_emitter,
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

procedure RequireContains(const AText, APattern: string; const ACode: Byte);
begin
  if Pos(APattern, AText) = 0 then
    Halt(ACode);
end;

procedure RequireNotContains(const AText, APattern: string; const ACode: Byte);
begin
  if Pos(APattern, AText) <> 0 then
    Halt(ACode);
end;

var
  BoolTypeId, LongWordTypeId, IntegerTypeId: LongInt;
  SymUnsignedDiv, SymUnsignedMod, SymSignedDiv, SymSignedMod: LongInt;
  SymUnsignedCmp, SymSignedCmp: LongInt;
  UnsignedLhs, UnsignedRhs, SignedLhs, SignedRhs: LongInt;
  ExprUnsignedDiv, ExprUnsignedMod, ExprSignedDiv, ExprSignedMod: LongInt;
  ExprUnsignedCmp, ExprSignedCmp: LongInt;
  NodeId: LongInt;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  IR: string;
begin
  Model := TSemanticModel.Create;
  try
    BoolTypeId := AddTypeWithFact('Boolean', sskBool, 1, False);
    LongWordTypeId := AddTypeWithFact('LongWord', sskInt, 32, False);
    IntegerTypeId := AddTypeWithFact('Integer', sskInt, 32, True);

    SymUnsignedDiv := Model.AddSymbol('uDiv', 'variable', '', LongWordTypeId, 0);
    SymUnsignedMod := Model.AddSymbol('uMod', 'variable', '', LongWordTypeId, 0);
    SymSignedDiv := Model.AddSymbol('sDiv', 'variable', '', IntegerTypeId, 0);
    SymSignedMod := Model.AddSymbol('sMod', 'variable', '', IntegerTypeId, 0);
    SymUnsignedCmp := Model.AddSymbol('uCmp', 'variable', '', BoolTypeId, 0);
    SymSignedCmp := Model.AddSymbol('sCmp', 'variable', '', BoolTypeId, 0);

    UnsignedLhs := AddIntLiteral(9, LongWordTypeId);
    UnsignedRhs := AddIntLiteral(4, LongWordTypeId);
    SignedLhs := AddIntLiteral(-9, IntegerTypeId);
    SignedRhs := AddIntLiteral(4, IntegerTypeId);

    ExprUnsignedDiv := AddBinaryOp('div', UnsignedLhs, UnsignedRhs, LongWordTypeId);
    ExprUnsignedMod := AddBinaryOp('mod', UnsignedLhs, UnsignedRhs, LongWordTypeId);
    ExprSignedDiv := AddBinaryOp('div', SignedLhs, SignedRhs, IntegerTypeId);
    ExprSignedMod := AddBinaryOp('mod', SignedLhs, SignedRhs, IntegerTypeId);
    ExprUnsignedCmp := AddCompareOp('<', UnsignedLhs, UnsignedRhs, BoolTypeId);
    ExprSignedCmp := AddCompareOp('<', SignedLhs, SignedRhs, BoolTypeId);

    Model.AddTypedHirNode('function-body-begin', 'TestStructuredSignedness', 0,
      IntegerTypeId, '0::i');

    Model.AddTypedHirNode('var-decl-runtime', 'uDiv', SymUnsignedDiv,
      LongWordTypeId, 'uDiv');
    NodeId := Model.AddTypedHirNode('assign-runtime', 'uDiv := 9 div 4',
      SymUnsignedDiv, LongWordTypeId, 'uDiv'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprUnsignedDiv);

    Model.AddTypedHirNode('var-decl-runtime', 'uMod', SymUnsignedMod,
      LongWordTypeId, 'uMod');
    NodeId := Model.AddTypedHirNode('assign-runtime', 'uMod := 9 mod 4',
      SymUnsignedMod, LongWordTypeId, 'uMod'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprUnsignedMod);

    Model.AddTypedHirNode('var-decl-runtime', 'sDiv', SymSignedDiv,
      IntegerTypeId, 'sDiv');
    NodeId := Model.AddTypedHirNode('assign-runtime', 'sDiv := -9 div 4',
      SymSignedDiv, IntegerTypeId, 'sDiv'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprSignedDiv);

    Model.AddTypedHirNode('var-decl-runtime', 'sMod', SymSignedMod,
      IntegerTypeId, 'sMod');
    NodeId := Model.AddTypedHirNode('assign-runtime', 'sMod := -9 mod 4',
      SymSignedMod, IntegerTypeId, 'sMod'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprSignedMod);

    Model.AddTypedHirNode('var-decl-runtime', 'uCmp', SymUnsignedCmp,
      BoolTypeId, 'uCmp');
    NodeId := Model.AddTypedHirNode('assign-runtime', 'uCmp := 9 < 4',
      SymUnsignedCmp, BoolTypeId, 'uCmp'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprUnsignedCmp);

    Model.AddTypedHirNode('var-decl-runtime', 'sCmp', SymSignedCmp,
      BoolTypeId, 'sCmp');
    NodeId := Model.AddTypedHirNode('assign-runtime', 'sCmp := -9 < 4',
      SymSignedCmp, BoolTypeId, 'sCmp'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprSignedCmp);

    Model.AddTypedHirNode('function-body-end', 'TestStructuredSignedness', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        IR := Emitter.AsText;
        RequireContains(IR, 'udiv i32', 1);
        RequireContains(IR, 'urem i32', 2);
        RequireContains(IR, 'icmp ult i32', 3);
        RequireContains(IR, 'sdiv i32', 4);
        RequireContains(IR, 'srem i32', 5);
        RequireContains(IR, 'icmp slt i32', 6);
        RequireNotContains(IR, 'icmp slt i32 9, 4', 7);
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
