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

function AddArrayElemAddressFromBase(const ABaseExprId, AIndexExprId,
  ATypeId: LongInt): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 2);
  Children[0] := ABaseExprId;
  Children[1] := AIndexExprId;
  Result := Model.AddHirExpr(
    shekArrayElem, ATypeId, 0, Children, 0, '', '', 0, shvcAddress
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

function HasInstrKind(const AFunc: THIRFunction;
  const AKind: THIRInstrKind): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
      if AFunc.Blocks[BlockIndex].Instrs[InstrIndex].Kind = AKind then
        Exit(True);
  Result := False;
end;

function HasRecordAllocaSlots(const AFunc: THIRFunction;
  const ASlotCount: LongInt): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
      if (AFunc.Blocks[BlockIndex].Instrs[InstrIndex].Kind = hikAlloca) and
        (AFunc.Blocks[BlockIndex].Instrs[InstrIndex].IntrinsicName =
         'record:' + IntToStr(ASlotCount)) then
        Exit(True);
  Result := False;
end;

var
  IntegerTypeId, PointerTypeId, RecordTypeId, InnerTypeId, OuterTypeId: LongInt;
  SymArr, SymNestedArr, SymP, SymRec, SymRecArr, SymSelf, SymStaticArr, SymX,
    SymY: LongInt;
  ExprFive, ExprOne, ExprXAddress, ExprAddressOfX, ExprDerefAddressOfX: LongInt;
  ExprArrElement, ExprNestedArrElement, ExprNestedOuterField,
    ExprNestedLeafField, ExprRecArrElement, ExprRecArrField,
    ExprStaticArrElement, ExprPValue, ExprDerefPRecord, ExprPField: LongInt;
  ExprRecAddress, ExprRecField, ExprSelfValue, ExprDerefSelf, ExprItemsField,
    ExprItemsElement, ExprItemsOuterElement, ExprItemsOuterField,
    ExprItemsLeafField: LongInt;
  NodeId: LongInt;
  Builder: THIRBuilder;
  Func: THIRFunction;
begin
  Model := TSemanticModel.Create;
  try
    IntegerTypeId := AddTypeWithFact('Integer', sskInt, 32, True);
    PointerTypeId := AddTypeWithFact('Pointer', sskPointer, 64, False);
    RecordTypeId := Model.AddType('TNode', 'declared');
    InnerTypeId := Model.AddType('TInner', 'declared');
    OuterTypeId := Model.AddType('TOuter', 'declared');

    SymX := Model.AddSymbol('x', 'variable', '', IntegerTypeId, 0);
    SymY := Model.AddSymbol('y', 'variable', '', IntegerTypeId, 0);
    SymArr := Model.AddSymbol('arr', 'variable', '', 0, 0);
    SymNestedArr := Model.AddSymbol('nestedArr', 'variable', '', 0, 0);
    SymRecArr := Model.AddSymbol('recArr', 'variable', '', 0, 0);
    SymStaticArr := Model.AddSymbol('staticArr', 'variable', '', 0, 0);
    SymSelf := Model.AddSymbol('self', 'parameter', '', RecordTypeId, 0);
    SymP := Model.AddSymbol('p', 'variable', '', PointerTypeId, 0);
    SymRec := Model.AddSymbol('rec', 'variable', '', RecordTypeId, 0);

    ExprFive := AddIntLiteral(5, IntegerTypeId);
    ExprOne := AddIntLiteral(1, IntegerTypeId);
    ExprXAddress := AddSymbolAddress(SymX, IntegerTypeId);
    ExprAddressOfX := AddAddressOf(ExprXAddress, PointerTypeId);
    ExprDerefAddressOfX := AddDeref(ExprAddressOfX, IntegerTypeId);
    ExprArrElement := AddArrayElemAddress(SymArr, ExprOne, IntegerTypeId);
    ExprNestedArrElement := AddArrayElemAddress(SymNestedArr, ExprOne,
      OuterTypeId);
    ExprNestedOuterField := AddFieldAddress(ExprNestedArrElement, InnerTypeId,
      0, 'A');
    ExprNestedLeafField := AddFieldAddress(ExprNestedOuterField, IntegerTypeId,
      0, 'B');
    ExprRecArrElement := AddArrayElemAddress(SymRecArr, ExprOne,
      RecordTypeId);
    ExprRecArrField := AddFieldAddress(ExprRecArrElement, IntegerTypeId, 1,
      'Value');
    ExprStaticArrElement := AddArrayElemAddress(SymStaticArr, ExprOne,
      IntegerTypeId);
    ExprPValue := AddSymbolValue(SymP, PointerTypeId);
    ExprDerefPRecord := AddDeref(ExprPValue, RecordTypeId);
    ExprPField := AddFieldAddress(ExprDerefPRecord, IntegerTypeId, 2,
      'Value');
    ExprRecAddress := AddSymbolAddress(SymRec, RecordTypeId);
    ExprRecField := AddFieldAddress(ExprRecAddress, IntegerTypeId, 0, 'X');
    ExprSelfValue := AddSymbolValue(SymSelf, PointerTypeId);
    ExprDerefSelf := AddDeref(ExprSelfValue, RecordTypeId);
    ExprItemsField := AddFieldAddress(ExprDerefSelf, PointerTypeId, 1,
      'FItems');
    ExprItemsElement := AddArrayElemAddressFromBase(ExprItemsField, ExprOne,
      IntegerTypeId);
    ExprItemsOuterElement := AddArrayElemAddressFromBase(ExprItemsField,
      ExprOne, OuterTypeId);
    ExprItemsOuterField := AddFieldAddress(ExprItemsOuterElement, InnerTypeId,
      0, 'A');
    ExprItemsLeafField := AddFieldAddress(ExprItemsOuterField, IntegerTypeId,
      0, 'B');

    Model.AddTypedHirNode('method-body-begin', 'TestAddress', 0,
      IntegerTypeId, '0::i');
    Model.AddTypedHirNode('var-decl-arr-runtime', 'arr', SymArr, 0, 'arr');
    Model.AddTypedHirNode('var-decl-arr-runtime', 'nestedArr', SymNestedArr, 0,
      'nestedArr');
    Model.AddTypedHirNode('var-decl-arr-runtime', 'recArr', SymRecArr, 0,
      'recArr');
    Model.AddConstValue('staticArr$arr_static', 1);
    Model.AddConstValue('staticArr$arr_low', 1);
    Model.AddConstValue('staticArr$arr_high', 3);
    Model.AddConstValue('staticArr$arr_len', 3);
    Model.AddTypedHirNode('var-decl-arr-runtime', 'staticArr', SymStaticArr,
      0, 'staticArr'#9'static'#9'1'#9'3'#9'3');
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'p', SymP, PointerTypeId,
      'p');
    Model.AddTypedHirNode('var-decl-record-runtime', 'rec', SymRec,
      RecordTypeId, 'rec'#9'2');
    Model.AddTypedHirNode('var-decl-runtime', 'x', SymX, IntegerTypeId, 'x');
    Model.AddTypedHirNode('var-decl-runtime', 'y', SymY, IntegerTypeId, 'y');

    NodeId := Model.AddTypedHirNode('assign-runtime', 'x := 5',
      SymX, IntegerTypeId, 'x'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprFive);

    NodeId := Model.AddTypedHirNode('assign-runtime', 'y := (@x)^',
      SymY, IntegerTypeId, 'y'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprDerefAddressOfX);

    NodeId := Model.AddTypedHirNode('assign-runtime', 'y := arr[1]',
      SymY, IntegerTypeId, 'y'#9'int 99'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprArrElement);

    NodeId := Model.AddTypedHirNode('assign-runtime', 'y := nestedArr[1].A.B',
      SymY, IntegerTypeId, 'y'#9'int 123'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprNestedLeafField);

    NodeId := Model.AddTypedHirNode('assign-runtime', 'y := FItems[1]',
      SymY, IntegerTypeId, 'y'#9'int 99'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprItemsElement);

    NodeId := Model.AddTypedHirNode('assign-runtime', 'y := FItems[1].A.B',
      SymY, IntegerTypeId, 'y'#9'int 123'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprItemsLeafField);

    NodeId := Model.AddTypedHirNode('assign-arr-elem-runtime',
      'arr[1] := 5', 0, IntegerTypeId,
      'missing'#9'int 99'#10#9'int 123'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprFive);
    Model.SetTypedHirNodeTargetExprId(NodeId, ExprArrElement);

    NodeId := Model.AddTypedHirNode('assign-arr-elem-runtime',
      'staticArr[1] := 5', 0, IntegerTypeId,
      'staticArr'#9'int 99'#10#9'int 5'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprFive);
    Model.SetTypedHirNodeTargetExprId(NodeId, ExprStaticArrElement);

    NodeId := Model.AddTypedHirNode('assign-arr-elem-runtime',
      'recArr[1].Value := 5', 0, IntegerTypeId,
      'recArr'#9'int 99'#10#9'int 123'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprFive);
    Model.SetTypedHirNodeTargetExprId(NodeId, ExprRecArrField);

    NodeId := Model.AddTypedHirNode('assign-arr-elem-runtime',
      'nestedArr[1].A.B := 5', 0, IntegerTypeId,
      'nestedArr'#9'int 99'#10#9'int 123'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprFive);
    Model.SetTypedHirNodeTargetExprId(NodeId, ExprNestedLeafField);

    NodeId := Model.AddTypedHirNode('assign-arr-elem-runtime',
      'FItems[1] := 5', 0, IntegerTypeId,
      'self'#9'1'#9'int 99'#10#9'int 123'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprFive);
    Model.SetTypedHirNodeTargetExprId(NodeId, ExprItemsElement);

    NodeId := Model.AddTypedHirNode('assign-arr-elem-runtime',
      'FItems[1].A.B := 5', 0, IntegerTypeId,
      'self'#9'1'#9'int 99'#10#9'int 123'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprFive);
    Model.SetTypedHirNodeTargetExprId(NodeId, ExprItemsLeafField);

    NodeId := Model.AddTypedHirNode('assign-runtime', 'y := p^.Value',
      SymY, IntegerTypeId, 'y'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprPField);

    NodeId := Model.AddTypedHirNode('field-store-runtime',
      'p^.Value := 5', 0, IntegerTypeId, 'missing'#9'99'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprFive);
    Model.SetTypedHirNodeTargetExprId(NodeId, ExprPField);

    NodeId := Model.AddTypedHirNode('record-field-store-runtime',
      'rec.X := 5', 0, IntegerTypeId, 'missing'#9'77'#9'int 0'#10);
    Model.SetTypedHirNodeExprId(NodeId, ExprFive);
    Model.SetTypedHirNodeTargetExprId(NodeId, ExprRecField);
    Model.AddTypedHirNode('function-body-end', 'TestAddress', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      if not FindFunction(Builder.Module, 'TestAddress', Func) then
        Halt(1);
      if not HasRuntimeLoadWidth(Builder.Module, Func, 32, True) then
        Halt(2);
      if not HasStoreWidth(Builder.Module, Func, 32, True) then
        Halt(3);
      if not HasIntrinsic(Func, 'gep_i64') then
        Halt(4);
      if CountIntrinsic(Func, 'gep_i64') < 8 then
        Halt(5);
      if HasConstLoad(Func, 'const:99') then
        Halt(6);
      if HasConstLoad(Func, 'const:123') then
        Halt(7);
      if not HasRecordAllocaSlots(Func, 3) then
        Halt(8);
      if not HasInstrKind(Func, hikSub) then
        Halt(9);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;
end.
