program test_hir_builder_structured_address;

{$mode objfpc}{$H+}

uses
  SysUtils,
  np_hir_builder,
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

function AddSymbolAddress(const ASymbolId, ATypeId: LongInt): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 0);
  Result := Model.AddHirExpr(
    shekSymbolAddress, ATypeId, ASymbolId, Children, 0, '', '', 0, shvcAddress
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

function AddAddressOf(const AChildExprId, APointerTypeId: LongInt): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 1);
  Children[0] := AChildExprId;
  Result := Model.AddHirExpr(
    shekAddressOf, APointerTypeId, 0, Children, 0, '', '', 0, shvcScalar
  );
end;

function AddDeref(const AChildExprId, ATypeId: LongInt): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 1);
  Children[0] := AChildExprId;
  Result := Model.AddHirExpr(
    shekDeref, ATypeId, 0, Children, 0, '', '', 0, shvcAddress
  );
end;

function AddArrayElemAddress(const ASymbolId, AIndexExprId,
  ATypeId: LongInt): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 1);
  Children[0] := AIndexExprId;
  Result := Model.AddHirExpr(
    shekArrayElem, ATypeId, ASymbolId, Children, 0, '', '', 0, shvcAddress
  );
end;

function AddFieldAddress(const ABaseExprId, AFieldTypeId: LongInt;
  const AFieldIndex: Int64; const AFieldName: string): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 1);
  Children[0] := ABaseExprId;
  Result := Model.AddHirExpr(
    shekField, AFieldTypeId, 0, Children, AFieldIndex, AFieldName, '', 0,
    shvcAddress
  );
end;

function TypeIsIntWidth(const AModule: THIRModule; const ATypeId: THIRTypeId;
  const ABitWidth: Byte; const ASigned: Boolean): Boolean;
var
  TypeRec: THIRTypeRec;
begin
  if ATypeId = 0 then
    Exit(False);
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

function HasConstLoad(const AFunc: THIRFunction; const AName: string): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
      if (AFunc.Blocks[BlockIndex].Instrs[InstrIndex].Kind = hikLoad) and
        (AFunc.Blocks[BlockIndex].Instrs[InstrIndex].IntrinsicName = AName) then
        Exit(True);
  Result := False;
end;

function HasRuntimeLoadWidth(const AModule: THIRModule;
  const AFunc: THIRFunction; const ABitWidth: Byte;
  const ASigned: Boolean): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
  Instr: THIRInstr;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
    begin
      Instr := AFunc.Blocks[BlockIndex].Instrs[InstrIndex];
      if (Instr.Kind = hikLoad) and (Instr.IntrinsicName = '') and
        TypeIsIntWidth(AModule, Instr.TypeId, ABitWidth, ASigned) then
        Exit(True);
    end;
  Result := False;
end;

function HasStoreWidth(const AModule: THIRModule; const AFunc: THIRFunction;
  const ABitWidth: Byte; const ASigned: Boolean): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
  Instr: THIRInstr;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
    begin
      Instr := AFunc.Blocks[BlockIndex].Instrs[InstrIndex];
      if (Instr.Kind = hikStore) and
        TypeIsIntWidth(AModule, Instr.TypeId, ABitWidth, ASigned) then
        Exit(True);
    end;
  Result := False;
end;

function HasIntrinsic(const AFunc: THIRFunction;
  const AIntrinsicName: string): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
      if (AFunc.Blocks[BlockIndex].Instrs[InstrIndex].Kind = hikIntrinsic) and
        (AFunc.Blocks[BlockIndex].Instrs[InstrIndex].IntrinsicName =
         AIntrinsicName) then
        Exit(True);
  Result := False;
end;

function CountIntrinsic(const AFunc: THIRFunction;
  const AIntrinsicName: string): LongInt;
var
  BlockIndex, InstrIndex: LongInt;
begin
  Result := 0;
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
      if (AFunc.Blocks[BlockIndex].Instrs[InstrIndex].Kind = hikIntrinsic) and
        (AFunc.Blocks[BlockIndex].Instrs[InstrIndex].IntrinsicName =
         AIntrinsicName) then
        Inc(Result);
end;

var
  IntegerTypeId, PointerTypeId, RecordTypeId: LongInt;
  SymArr, SymP, SymX, SymY: LongInt;
  ExprFive, ExprOne, ExprXAddress, ExprAddressOfX, ExprDerefAddressOfX: LongInt;
  ExprArrElement, ExprPValue, ExprDerefPRecord, ExprPField: LongInt;
  NodeId: LongInt;
  Builder: THIRBuilder;
  Func: THIRFunction;
begin
  Model := TSemanticModel.Create;
  try
    IntegerTypeId := AddTypeWithFact('Integer', sskInt, 32, True);
    PointerTypeId := AddTypeWithFact('Pointer', sskPointer, 64, False);
    RecordTypeId := Model.AddType('TNode', 'declared');

    SymX := Model.AddSymbol('x', 'variable', '', IntegerTypeId, 0);
    SymY := Model.AddSymbol('y', 'variable', '', IntegerTypeId, 0);
    SymArr := Model.AddSymbol('arr', 'variable', '', 0, 0);
    SymP := Model.AddSymbol('p', 'variable', '', PointerTypeId, 0);

    ExprFive := AddIntLiteral(5, IntegerTypeId);
    ExprOne := AddIntLiteral(1, IntegerTypeId);
    ExprXAddress := AddSymbolAddress(SymX, IntegerTypeId);
    ExprAddressOfX := AddAddressOf(ExprXAddress, PointerTypeId);
    ExprDerefAddressOfX := AddDeref(ExprAddressOfX, IntegerTypeId);
    ExprArrElement := AddArrayElemAddress(SymArr, ExprOne, IntegerTypeId);
    ExprPValue := AddSymbolValue(SymP, PointerTypeId);
    ExprDerefPRecord := AddDeref(ExprPValue, RecordTypeId);
    ExprPField := AddFieldAddress(ExprDerefPRecord, IntegerTypeId, 2,
      'Value');

    Model.AddTypedHirNode('function-body-begin', 'TestAddress', 0,
      IntegerTypeId, '0::i');
    Model.AddTypedHirNode('var-decl-arr-runtime', 'arr', SymArr, 0, 'arr');
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'p', SymP, PointerTypeId,
      'p');
    Model.AddTypedHirNode('var-decl-runtime', 'x', SymX, IntegerTypeId, 'x');
    Model.AddTypedHirNode('var-decl-runtime', 'y', SymY, IntegerTypeId, 'y');

    NodeId := Model.AddTypedHirNode('assign-runtime', 'x := 5',
      SymX, IntegerTypeId, 'x'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprFive);

    NodeId := Model.AddTypedHirNode('assign-runtime', 'y := (@x)^',
      SymY, IntegerTypeId, 'y'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprDerefAddressOfX);

    NodeId := Model.AddTypedHirNode('assign-runtime', 'y := arr[1]',
      SymY, IntegerTypeId, 'y'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprArrElement);

    NodeId := Model.AddTypedHirNode('assign-runtime', 'y := p^.Value',
      SymY, IntegerTypeId, 'y'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprPField);

    NodeId := Model.AddTypedHirNode('field-store-runtime',
      'p^.Value := 5', 0, IntegerTypeId, 'p'#9'2'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprFive);
    Model.AddTypedHirNode('function-body-end', 'TestAddress', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      if not FindFunction(Builder.Module, 'TestAddress', Func) then
        Halt(1);
      if HasConstLoad(Func, 'const:0') then
        Halt(2);
      if not HasRuntimeLoadWidth(Builder.Module, Func, 32, True) then
        Halt(3);
      if not HasStoreWidth(Builder.Module, Func, 32, True) then
        Halt(4);
      if not HasIntrinsic(Func, 'gep_i64') then
        Halt(5);
      if CountIntrinsic(Func, 'gep_i64') < 3 then
        Halt(6);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;
end.
