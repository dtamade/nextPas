program test_hir_builder_expr_fallback;

{$mode objfpc}{$H+}

uses
  SysUtils, np_semantic_model, np_hir_builder, np_hir_model, np_hir_types;

function AddTypeWithFact(const AModel: TSemanticModel; const AName: string;
  const AKind: TSemanticScalarKind; const ABitWidth: LongInt;
  const ASigned: Boolean): LongInt;
begin
  Result := AModel.AddType(AName, 'builtin');
  AModel.SetTypeScalarFact(Result, AKind, ABitWidth, ASigned);
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

function HasPointerStore(const AModule: THIRModule;
  const AFunc: THIRFunction): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
  Instr: THIRInstr;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
    begin
      Instr := AFunc.Blocks[BlockIndex].Instrs[InstrIndex];
      if (Instr.Kind = hikStore) and
        (AModule.Types.GetType(Instr.TypeId).Kind = htkPointer) then
        Exit(True);
    end;
  Result := False;
end;

function HasIntStore(const AModule: THIRModule; const AFunc: THIRFunction;
  const ABitWidth: Byte): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
  Instr: THIRInstr;
  TypeRec: THIRTypeRec;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
    begin
      Instr := AFunc.Blocks[BlockIndex].Instrs[InstrIndex];
      TypeRec := AModule.Types.GetType(Instr.TypeId);
      if (Instr.Kind = hikStore) and (TypeRec.Kind = htkInt) and
        (TypeRec.BitWidth = ABitWidth) then
        Exit(True);
  end;
  Result := False;
end;

function HasCallTarget(const AFunc: THIRFunction;
  const ATarget: string): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
  Instr: THIRInstr;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
    begin
      Instr := AFunc.Blocks[BlockIndex].Instrs[InstrIndex];
      if (Instr.Kind = hikCall) and (Instr.CallTarget = ATarget) then
        Exit(True);
  end;
  Result := False;
end;

function HasIntrinsic(const AFunc: THIRFunction;
  const AIntrinsicName: string): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
  Instr: THIRInstr;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
    begin
      Instr := AFunc.Blocks[BlockIndex].Instrs[InstrIndex];
      if (Instr.Kind = hikIntrinsic) and
        (Instr.IntrinsicName = AIntrinsicName) then
        Exit(True);
    end;
  Result := False;
end;

var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  ExprResult: THIRExprResult;
  ExprId, LiteralExprId, UnsupportedExprId, BadSymbolExprId, PartialExprId,
    CallExprId, IntTypeId, PtrTypeId, NodeId, ReceiverSymbolId,
    ReceiverBaseExprId, ReceiverExprId, ArgExprId: LongInt;
  Children: array of LongInt;
  Func: THIRFunction;
begin
  Model := TSemanticModel.Create;
  try
    SetLength(Children, 0);
    ExprId := Model.AddHirExpr(
      shekInvalid,
      0,
      0,
      Children,
      0,
      '',
      '',
      0,
      shvcNone
    );
    Builder := THIRBuilder.Create(Model);
    try
      if Builder.LowerExpr(ExprId, ExprResult) then
        Halt(1);
      if (ExprResult.ValueId <> 0) or (ExprResult.TypeId <> 0) or
        (ExprResult.AddressValueId <> 0) or (ExprResult.ValueClass <> shvcNone) then
        Halt(2);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  Model := TSemanticModel.Create;
  try
    SetLength(Children, 0);
    LiteralExprId := Model.AddHirExpr(
      shekIntLiteral,
      0,
      0,
      Children,
      99,
      '',
      '',
      0,
      shvcScalar
    );
    UnsupportedExprId := Model.AddHirExpr(
      shekVirtualCall,
      0,
      0,
      Children,
      0,
      '',
      '',
      0,
      shvcScalar
    );
    SetLength(Children, 2);
    Children[0] := LiteralExprId;
    Children[1] := UnsupportedExprId;
    PartialExprId := Model.AddHirExpr(
      shekBinaryOp,
      0,
      0,
      Children,
      0,
      '',
      '+',
      0,
      shvcScalar
    );
    Model.AddTypedHirNode('var-decl-runtime', 'x', 0, 0, 'x');
    NodeId := Model.AddTypedHirNode(
      'assign-runtime', 'x := fallback', 0, 0, 'x'#9'int 7'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, PartialExprId);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      if Builder.Module.FunctionCount = 0 then
        Halt(3);
      Func := Builder.Module.FunctionAt(0);
      if not HasConstLoad(Func, 'const:7') then
        Halt(4);
      if HasConstLoad(Func, 'const:99') then
        Halt(5);
    finally
      Builder.Free;
    end;

  finally
    Model.Free;
  end;

  Model := TSemanticModel.Create;
  try
    SetLength(Children, 0);
    LiteralExprId := Model.AddHirExpr(
      shekIntLiteral,
      0,
      0,
      Children,
      123,
      '',
      '',
      0,
      shvcScalar
    );
    BadSymbolExprId := Model.AddHirExpr(
      shekSymbolValue,
      0,
      999,
      Children,
      0,
      '',
      '',
      0,
      shvcScalar
    );
    SetLength(Children, 2);
    Children[0] := LiteralExprId;
    Children[1] := BadSymbolExprId;
    PartialExprId := Model.AddHirExpr(
      shekBinaryOp,
      0,
      0,
      Children,
      0,
      '',
      '+',
      0,
      shvcScalar
    );
    Model.AddTypedHirNode('var-decl-runtime', 'z', 0, 0, 'z');
    NodeId := Model.AddTypedHirNode(
      'assign-runtime', 'z := fallback', 0, 0, 'z'#9'int 11'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, PartialExprId);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      if Builder.Module.FunctionCount = 0 then
        Halt(6);
      Func := Builder.Module.FunctionAt(0);
      if not HasConstLoad(Func, 'const:11') then
        Halt(7);
      if HasConstLoad(Func, 'const:123') then
        Halt(8);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'src', 0, 0, 'src');
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'dst', 0, 0, 'dst');
    Model.AddTypedHirNode('var-decl-runtime', 'value', 0, 0, 'value');
    Model.AddTypedHirNode(
      'assign-runtime', 'dst := src blob ptr', 0, 0, 'dst'#9'var src'#10
    );
    Model.AddTypedHirNode(
      'assign-runtime', 'src^ := value blob int', 0, 0, '*src'#9'var value'#10
    );

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      if Builder.Module.FunctionCount = 0 then
        Halt(9);
      Func := Builder.Module.FunctionAt(0);
      if not HasPointerStore(Builder.Module, Func) then
        Halt(10);
      if not HasIntStore(Builder.Module, Func, 64) then
        Halt(11);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  Model := TSemanticModel.Create;
  try
    IntTypeId := AddTypeWithFact(Model, 'Integer', sskInt, 64, True);
    PtrTypeId := AddTypeWithFact(Model, 'Pointer', sskPointer, 64, False);
    SetLength(Children, 0);
    LiteralExprId := Model.AddHirExpr(
      shekIntLiteral,
      IntTypeId,
      0,
      Children,
      41,
      '',
      '',
      0,
      shvcScalar
    );
    SetLength(Children, 1);
    Children[0] := LiteralExprId;
    CallExprId := Model.AddHirExpr(
      shekCall,
      IntTypeId,
      0,
      Children,
      0,
      'AddOne',
      'i',
      0,
      shvcScalar
    );
    Model.AddTypedHirNode('function-body-begin', 'AddOne', 0, 0, '1:i');
    Model.AddTypedHirNode('ret-runtime', 'AddOne', 0, 0, 'int 42'#10);
    Model.AddTypedHirNode('function-body-end', 'AddOne', 0, 0, '');
    Model.AddTypedHirNode('var-decl-runtime', 'x', 0, 0, 'x');
    NodeId := Model.AddTypedHirNode(
      'assign-runtime', 'x := structured call', 0, 0,
      'x'#9'int 0'#10'call WrongAddOne 1'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, CallExprId);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Func := Builder.Module.FunctionAt(0);
      if not HasCallTarget(Func, 'AddOne') then
        Halt(12);
      if HasCallTarget(Func, 'WrongAddOne') then
        Halt(13);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  Model := TSemanticModel.Create;
  try
    IntTypeId := AddTypeWithFact(Model, 'Integer', sskInt, 64, True);
    PtrTypeId := AddTypeWithFact(Model, 'Pointer', sskPointer, 64, False);
    ReceiverSymbolId := Model.AddSymbol('calc', 'var', 'test', PtrTypeId, 0);
    SetLength(Children, 0);
    ReceiverBaseExprId := Model.AddHirExpr(
      shekSymbolValue,
      PtrTypeId,
      ReceiverSymbolId,
      Children,
      0,
      '',
      '',
      0,
      shvcScalar
    );
    SetLength(Children, 1);
    Children[0] := ReceiverBaseExprId;
    ReceiverExprId := Model.AddHirExpr(
      shekDeref,
      PtrTypeId,
      0,
      Children,
      0,
      '',
      '',
      0,
      shvcAddress
    );
    SetLength(Children, 0);
    ArgExprId := Model.AddHirExpr(
      shekIntLiteral,
      IntTypeId,
      0,
      Children,
      41,
      '',
      '',
      0,
      shvcScalar
    );
    SetLength(Children, 2);
    Children[0] := ReceiverExprId;
    Children[1] := ArgExprId;
    CallExprId := Model.AddHirExpr(
      shekVirtualCall,
      IntTypeId,
      0,
      Children,
      0,
      'TCalc.Add',
      'pi',
      0,
      shvcScalar
    );
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'calc', 0, 0, 'calc');
    Model.AddTypedHirNode('var-decl-runtime', 'x', 0, 0, 'x');
    NodeId := Model.AddTypedHirNode(
      'assign-runtime', 'x := structured virtual call', 0, 0,
      'x'#9'var calc'#10'int 41'#10'call WrongVirt 2'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, CallExprId);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Func := Builder.Module.FunctionAt(0);
      if not HasIntrinsic(Func, 'vcall') then
        Halt(17);
      if HasCallTarget(Func, 'WrongVirt') then
        Halt(18);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  Model := TSemanticModel.Create;
  try
    IntTypeId := AddTypeWithFact(Model, 'Integer', sskInt, 64, True);
    PtrTypeId := AddTypeWithFact(Model, 'Pointer', sskPointer, 64, False);
    ReceiverSymbolId := Model.AddSymbol('counter', 'var', 'test', PtrTypeId, 0);
    SetLength(Children, 0);
    ReceiverBaseExprId := Model.AddHirExpr(
      shekSymbolValue,
      PtrTypeId,
      ReceiverSymbolId,
      Children,
      0,
      '',
      '',
      0,
      shvcScalar
    );
    SetLength(Children, 1);
    Children[0] := ReceiverBaseExprId;
    ReceiverExprId := Model.AddHirExpr(
      shekDeref,
      PtrTypeId,
      0,
      Children,
      0,
      '',
      '',
      0,
      shvcAddress
    );
    SetLength(Children, 1);
    Children[0] := ReceiverExprId;
    CallExprId := Model.AddHirExpr(
      shekInterfaceCall,
      IntTypeId,
      0,
      Children,
      0,
      'ICounter.Count',
      'p',
      0,
      shvcScalar
    );
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'counter', 0, 0, 'counter');
    Model.AddTypedHirNode('var-decl-runtime', 'y', 0, 0, 'y');
    NodeId := Model.AddTypedHirNode(
      'assign-runtime', 'y := structured interface call', 0, 0,
      'y'#9'var counter'#10'call WrongCount 1'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, CallExprId);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Func := Builder.Module.FunctionAt(0);
      if not HasIntrinsic(Func, 'vcall') then
        Halt(19);
      if HasCallTarget(Func, 'WrongCount') then
        Halt(20);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  Model := TSemanticModel.Create;
  try
    PtrTypeId := AddTypeWithFact(Model, 'Pointer', sskPointer, 64, False);
    SetLength(Children, 0);
    CallExprId := Model.AddHirExpr(
      shekCall,
      PtrTypeId,
      0,
      Children,
      0,
      'MakeNode',
      '',
      0,
      shvcScalar
    );
    Model.AddTypedHirNode('function-body-begin', 'MakeNode', 0, 0, '0::p');
    Model.AddTypedHirNode('ret-runtime', 'MakeNode', 0, 0, 'null'#10);
    Model.AddTypedHirNode('function-body-end', 'MakeNode', 0, 0, '');
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'chosen', 0, 0, 'chosen');
    NodeId := Model.AddTypedHirNode(
      'assign-runtime', 'chosen := structured ptr call', 0, 0,
      'chosen'#9'call WrongMakeNode 0'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, CallExprId);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Func := Builder.Module.FunctionAt(0);
      if not HasCallTarget(Func, 'MakeNode') then
        Halt(14);
      if HasCallTarget(Func, 'WrongMakeNode') then
        Halt(15);
      if not HasPointerStore(Builder.Module, Func) then
        Halt(16);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;
end.
