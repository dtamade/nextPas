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

function HasCallWithPointerArg(const AModule: THIRModule;
  const AFunc: THIRFunction; const ATarget: string;
  const AArgIndex: LongInt): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
  Instr: THIRInstr;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
    begin
      Instr := AFunc.Blocks[BlockIndex].Instrs[InstrIndex];
      if (Instr.Kind = hikCall) and (Instr.CallTarget = ATarget) and
        (AArgIndex >= 0) and (AArgIndex <= High(Instr.Operands)) and
        (Instr.Operands[AArgIndex].TypeId <> 0) and
        (AModule.Types.GetType(Instr.Operands[AArgIndex].TypeId).Kind = htkPointer) then
        Exit(True);
    end;
  Result := False;
end;

function TryFindInstrByResultId(const AFunc: THIRFunction;
  const AValueId: THIRValueId; out AInstr: THIRInstr): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
    begin
      AInstr := AFunc.Blocks[BlockIndex].Instrs[InstrIndex];
      if AInstr.ResultId = AValueId then
        Exit(True);
    end;
  Result := False;
end;

function HasCallArgProducedByKind(const AFunc: THIRFunction;
  const ATarget: string; const AArgIndex: LongInt;
  const AExpectedKind: THIRInstrKind): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
  Instr, SourceInstr: THIRInstr;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
    begin
      Instr := AFunc.Blocks[BlockIndex].Instrs[InstrIndex];
      if (Instr.Kind = hikCall) and (Instr.CallTarget = ATarget) and
        (AArgIndex >= 0) and (AArgIndex <= High(Instr.Operands)) and
        TryFindInstrByResultId(AFunc, Instr.Operands[AArgIndex].ValueId,
          SourceInstr) and (SourceInstr.Kind = AExpectedKind) then
        Exit(True);
    end;
  Result := False;
end;

function HasIntrinsicArgProducedByKind(const AFunc: THIRFunction;
  const AIntrinsicName: string; const AArgIndex: LongInt;
  const AExpectedKind: THIRInstrKind): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
  Instr, SourceInstr: THIRInstr;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
    begin
      Instr := AFunc.Blocks[BlockIndex].Instrs[InstrIndex];
      if (Instr.Kind = hikIntrinsic) and
        (Instr.IntrinsicName = AIntrinsicName) and
        (AArgIndex >= 0) and (AArgIndex <= High(Instr.Operands)) and
        TryFindInstrByResultId(AFunc, Instr.Operands[AArgIndex].ValueId,
          SourceInstr) and (SourceInstr.Kind = AExpectedKind) then
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
    ReceiverBaseExprId, ReceiverExprId, ArgExprId, ClassTypeId: LongInt;
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
    IntTypeId := AddTypeWithFact(Model, 'Integer', sskInt, 64, True);
    PtrTypeId := AddTypeWithFact(Model, 'Pointer', sskPointer, 64, False);
    ClassTypeId := Model.AddType('TNode', 'declared');
    ReceiverSymbolId := Model.AddSymbol('counter', 'var', 'test', PtrTypeId, 0);
    ExprId := Model.AddSymbol('value', 'var', 'test', IntTypeId, 0);
    BadSymbolExprId := Model.AddSymbol('base', 'var', 'test', PtrTypeId, 0);
    NodeId := Model.AddSymbol('node', 'var', 'test', ClassTypeId, 0);

    SetLength(Children, 0);
    ArgExprId := Model.AddHirExpr(
      shekSymbolAddress,
      IntTypeId,
      ExprId,
      Children,
      0,
      '',
      '',
      0,
      shvcAddress
    );
    SetLength(Children, 1);
    Children[0] := ArgExprId;
    CallExprId := Model.AddHirExpr(
      shekCall,
      IntTypeId,
      0,
      Children,
      0,
      'Bump',
      'r',
      0,
      shvcScalar
    );

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
    SetLength(Children, 2);
    Children[0] := ReceiverExprId;
    Children[1] := ArgExprId;
    PartialExprId := Model.AddHirExpr(
      shekCall,
      IntTypeId,
      0,
      Children,
      0,
      'TCounter.Touch',
      'pr',
      0,
      shvcScalar
    );

    SetLength(Children, 0);
    LiteralExprId := Model.AddHirExpr(
      shekSymbolAddress,
      ClassTypeId,
      NodeId,
      Children,
      0,
      '',
      '',
      0,
      shvcAddress
    );
    SetLength(Children, 0);
    UnsupportedExprId := Model.AddHirExpr(
      shekSymbolValue,
      PtrTypeId,
      BadSymbolExprId,
      Children,
      0,
      '',
      '',
      0,
      shvcScalar
    );
    SetLength(Children, 1);
    Children[0] := UnsupportedExprId;
    BadSymbolExprId := Model.AddHirExpr(
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
    SetLength(Children, 2);
    Children[0] := BadSymbolExprId;
    Children[1] := LiteralExprId;
    UnsupportedExprId := Model.AddHirExpr(
      shekVirtualCall,
      IntTypeId,
      0,
      Children,
      0,
      'TVirtualNodeUser.TouchNode',
      'pr',
      0,
      shvcScalar
    );

    Model.AddTypedHirNode('function-body-begin', 'Bump', 0, 0, '1:r:i');
    Model.AddTypedHirNode('ret-runtime', 'Bump', 0, 0, 'int 0'#10);
    Model.AddTypedHirNode('function-body-end', 'Bump', 0, 0, '');
    Model.AddTypedHirNode('method-body-begin', 'TCounter.Touch', 0, 0, '2:pr:i');
    Model.AddTypedHirNode('ret-runtime', 'TCounter.Touch', 0, 0, 'int 0'#10);
    Model.AddTypedHirNode('function-body-end', 'TCounter.Touch', 0, 0, '');
    Model.AddTypedHirNode('method-body-begin', 'TVirtualNodeUser.TouchNode', 0, 0, '2:pr:i');
    Model.AddTypedHirNode('ret-runtime', 'TVirtualNodeUser.TouchNode', 0, 0, 'int 0'#10);
    Model.AddTypedHirNode('function-body-end', 'TVirtualNodeUser.TouchNode', 0, 0, '');

    Model.AddTypedHirNode('var-decl-runtime', 'value', 0, 0, 'value');
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'counter', 0, 0, 'counter');
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'base', 0, 0, 'base');
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'node', 0, 0, 'node');

    NodeId := Model.AddTypedHirNode(
      'call-runtime', 'Bump', 0, 0,
      'WrongBump'#9'varref value'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, CallExprId);
    NodeId := Model.AddTypedHirNode(
      'call-runtime', 'TCounter.Touch', 0, 0,
      'WrongTouch'#9'var counter'#10#9'varref value'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, PartialExprId);
    NodeId := Model.AddTypedHirNode(
      'call-runtime', 'TVirtualNodeUser.TouchNode', 0, 0,
      'WrongTouchNode'#9'var base'#10#9'varref node'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, UnsupportedExprId);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Func := Builder.Module.FunctionAt(0);
      if not HasCallTarget(Func, 'Bump') then
        Halt(38);
      if HasCallTarget(Func, 'WrongBump') then
        Halt(39);
      if not HasCallWithPointerArg(Builder.Module, Func, 'Bump', 0) then
        Halt(40);
      if not HasCallTarget(Func, 'TCounter.Touch') then
        Halt(41);
      if HasCallTarget(Func, 'WrongTouch') then
        Halt(42);
      if not HasCallArgProducedByKind(Func, 'TCounter.Touch', 1, hikAlloca) then
        Halt(43);
      if not HasIntrinsic(Func, 'vcall') then
        Halt(44);
      if HasCallTarget(Func, 'WrongTouchNode') then
        Halt(45);
      if not HasIntrinsicArgProducedByKind(Func, 'vcall', 2, hikAlloca) then
        Halt(46);
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

  Model := TSemanticModel.Create;
  try
    IntTypeId := AddTypeWithFact(Model, 'Integer', sskInt, 64, True);
    PtrTypeId := AddTypeWithFact(Model, 'Pointer', sskPointer, 64, False);
    ClassTypeId := Model.AddType('TCounter', 'declared');
    ReceiverSymbolId := Model.AddSymbol('counter', 'var', 'test', ClassTypeId, 0);
    ExprId := Model.AddSymbol('value', 'var', 'test', IntTypeId, 0);

    SetLength(Children, 0);
    ArgExprId := Model.AddHirExpr(
      shekSymbolAddress,
      IntTypeId,
      ExprId,
      Children,
      0,
      '',
      '',
      0,
      shvcAddress
    );
    SetLength(Children, 1);
    Children[0] := ArgExprId;
    CallExprId := Model.AddHirExpr(
      shekCall,
      IntTypeId,
      0,
      Children,
      0,
      'Bump',
      'r',
      0,
      shvcScalar
    );
    Model.AddTypedHirNode('function-body-begin', 'Bump', 0, 0, '1:r:i');
    Model.AddTypedHirNode('ret-runtime', 'Bump', 0, 0, 'int 0'#10);
    Model.AddTypedHirNode('function-body-end', 'Bump', 0, 0, '');
    Model.AddTypedHirNode('var-decl-runtime', 'value', 0, 0, 'value');
    Model.AddTypedHirNode('var-decl-runtime', 'a', 0, 0, 'a');
    NodeId := Model.AddTypedHirNode(
      'assign-runtime', 'a := structured var call', 0, 0,
      'a'#9'int 0'#10'call WrongBump 1'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, CallExprId);

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
      ClassTypeId,
      0,
      Children,
      0,
      '',
      '',
      0,
      shvcAddress
    );
    SetLength(Children, 2);
    Children[0] := ReceiverExprId;
    Children[1] := ArgExprId;
    PartialExprId := Model.AddHirExpr(
      shekCall,
      IntTypeId,
      0,
      Children,
      0,
      'TCounter.Touch',
      'pr',
      0,
      shvcScalar
    );
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'counter', 0, 0, 'counter');
    Model.AddTypedHirNode('var-decl-runtime', 'b', 0, 0, 'b');
    NodeId := Model.AddTypedHirNode(
      'assign-runtime', 'b := structured var member call', 0, 0,
      'b'#9'int 0'#10'call WrongTouch 2'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, PartialExprId);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Func := Builder.Module.FunctionAt(0);
      if not HasCallWithPointerArg(Builder.Module, Func, 'Bump', 0) then
        Halt(21);
      if not HasCallTarget(Func, 'Bump') then
        Halt(22);
      if not HasCallTarget(Func, 'TCounter.Touch') then
        Halt(23);
      if not HasCallArgProducedByKind(Func, 'TCounter.Touch', 1, hikAlloca) then
        Halt(24);
      if HasCallArgProducedByKind(Func, 'TCounter.Touch', 1, hikLoad) then
        Halt(25);
      if HasCallTarget(Func, 'WrongTouch') then
        Halt(26);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  Model := TSemanticModel.Create;
  try
    IntTypeId := AddTypeWithFact(Model, 'Integer', sskInt, 64, True);
    ClassTypeId := Model.AddType('TNode', 'declared');
    ExprId := Model.AddSymbol('node', 'var', 'test', ClassTypeId, 0);

    SetLength(Children, 0);
    ArgExprId := Model.AddHirExpr(
      shekSymbolAddress,
      ClassTypeId,
      ExprId,
      Children,
      0,
      '',
      '',
      0,
      shvcAddress
    );
    SetLength(Children, 1);
    Children[0] := ArgExprId;
    CallExprId := Model.AddHirExpr(
      shekCall,
      IntTypeId,
      0,
      Children,
      0,
      'UseNode',
      'r',
      0,
      shvcScalar
    );
    Model.AddTypedHirNode('function-body-begin', 'UseNode', 0, 0, '1:r:i');
    Model.AddTypedHirNode('ret-runtime', 'UseNode', 0, 0, 'int 0'#10);
    Model.AddTypedHirNode('function-body-end', 'UseNode', 0, 0, '');
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'node', 0, 0, 'node');
    Model.AddTypedHirNode('var-decl-runtime', 'x', 0, 0, 'x');
    NodeId := Model.AddTypedHirNode(
      'assign-runtime', 'x := structured class var call', 0, 0,
      'x'#9'int 0'#10'call WrongUseNode 1'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, CallExprId);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Func := Builder.Module.FunctionAt(0);
      if not HasCallTarget(Func, 'UseNode') then
        Halt(25);
      if HasCallTarget(Func, 'WrongUseNode') then
        Halt(26);
      if not HasCallArgProducedByKind(Func, 'UseNode', 0, hikAlloca) then
        Halt(27);
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
    ClassTypeId := Model.AddType('TNode', 'declared');
    ReceiverSymbolId := Model.AddSymbol('base', 'var', 'test', PtrTypeId, 0);
    ExprId := Model.AddSymbol('node', 'var', 'test', ClassTypeId, 0);

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
      shekSymbolAddress,
      ClassTypeId,
      ExprId,
      Children,
      0,
      '',
      '',
      0,
      shvcAddress
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
      'TVirtualNodeUser.UseNode',
      'pr',
      0,
      shvcScalar
    );
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'base', 0, 0, 'base');
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'node', 0, 0, 'node');
    Model.AddTypedHirNode('var-decl-runtime', 'y', 0, 0, 'y');
    NodeId := Model.AddTypedHirNode(
      'assign-runtime', 'y := structured virtual class var call', 0, 0,
      'y'#9'var base'#10'varref node'#10'call WrongVirtNode 2'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, CallExprId);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Func := Builder.Module.FunctionAt(0);
      if not HasIntrinsic(Func, 'vcall') then
        Halt(28);
      if HasCallTarget(Func, 'WrongVirtNode') then
        Halt(29);
      if not HasIntrinsicArgProducedByKind(Func, 'vcall', 2, hikAlloca) then
        Halt(30);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  Model := TSemanticModel.Create;
  try
    PtrTypeId := AddTypeWithFact(Model, 'Pointer', sskPointer, 64, False);
    Model.AddTypedHirNode('var-decl-arr-runtime', 'items', 0, 0, 'items');
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'node', 0, 0, 'node');
    NodeId := Model.AddTypedHirNode(
      'assign-arr-elem-runtime', 'items[0] := multiline ptr blob tail', 0, 0,
      'items'#9'int 0'#10#9'var node'#10'int 7'#10
    );

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Func := Builder.Module.FunctionAt(0);
      if not HasIntStore(Builder.Module, Func, 64) then
        Halt(34);
      if HasPointerStore(Builder.Module, Func) then
        Halt(35);
      if not HasConstLoad(Func, 'const:7') then
        Halt(36);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('function-body-begin', 'ClearNode', 0, 0, '1:v:i');
    Model.AddTypedHirNode('var-decl-varref-runtime', 'node', 0, 0, 'node');
    Model.AddTypedHirNode(
      'assign-runtime', 'node := nil', 0, 0,
      'node'#9'null'#10
    );
    Model.AddTypedHirNode('ret-runtime', 'ClearNode', 0, 0, 'int 0'#10);
    Model.AddTypedHirNode('function-body-end', 'ClearNode', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Func := Builder.Module.FunctionAt(1);
      if Func.Name <> 'ClearNode' then
        Halt(41);
      if not HasPointerStore(Builder.Module, Func) then
        Halt(42);
      if HasIntStore(Builder.Module, Func, 64) then
        Halt(43);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('method-body-begin', 'TNodeUser.UseNode', 0, 0, '2:pv:i');
    Model.AddTypedHirNode('var-decl-varref-runtime', 'node', 0, 0, 'node');
    Model.AddTypedHirNode('ret-runtime', 'TNodeUser.UseNode', 0, 0, 'int 0'#10);
    Model.AddTypedHirNode('function-body-end', 'TNodeUser.UseNode', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Func := Builder.Module.FunctionAt(1);
      if Func.Name <> 'TNodeUser.UseNode' then
        Halt(44);
      if Length(Func.Params) <> 2 then
        Halt(45);
      if not Func.Params[1].IsVar then
        Halt(46);
      if Builder.Module.Types.GetType(Func.Params[1].TypeId).Kind <> htkPointer then
        Halt(47);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;
end.
