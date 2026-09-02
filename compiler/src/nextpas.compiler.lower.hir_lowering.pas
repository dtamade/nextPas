{**
 * nextpas.compiler.ir.hir.lowering.pas
 *
 * AST→HIR 降级模块 — 从 sema/ 提取到 lower/ 桥接层
 *
 * 职责：将 AST 节点降级为 HIR 表达式/语句
 * 依赖方向：sema → lower → ir
 *
 * 对标：rustc 的 hir_lowering, FPC 的 code generation
 *}

unit nextpas.compiler.lower.hir_lowering;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.frontend.unit_graph,
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.sema.semantic_model,
  nextpas.compiler.sema.builtins,
  nextpas.compiler.sema.overload,
  nextpas.compiler.sema.runtime_vars,
  nextpas.compiler.ir.hir.model,
  nextpas.compiler.frontend.source_database,
  nextpas.compiler.diagnostics.sink;

type
  { 回调函数类型 — 用于桥接尚未提取到独立模块的方法 }

  TBuildTargetAddressExprFn = function(const Ctx: Pointer; const ATargetNode: TGreenNode;
    out AExprId: LongInt): Boolean;
  TBuildClassBaseAddressExprFn = function(const Ctx: Pointer; const ABaseName,
    AClassName: string; out AExprId: LongInt): Boolean;
  TBuildByRefArgumentAddressExprFn = function(const Ctx: Pointer;
    const AArgNode: TGreenNode; out AExprId: LongInt): Boolean;
  TBuildRuntimeArrayElementAddressHirExprFn = function(const Ctx: Pointer;
    const ANode: TGreenNode; out AExprId: LongInt): Boolean;
  TEvaluateIntegerConstantFn = function(const Ctx: Pointer; const ANode: TGreenNode;
    out AValue: Int64): Boolean;
  TInferExpressionTypeFn = function(const Ctx: Pointer;
    const ANode: TGreenNode): LongInt;
  TTypeIdForVariableFn = function(const Ctx: Pointer;
    const AName: string): LongInt;
  TTryGetDirectCallContractFn = function(const Ctx: Pointer; const ACallNode: TGreenNode;
    out ACalleeName, AParamKinds: string; out AResultTypeId: LongInt): Boolean;
  TTryGetDispatchedMemberCallContractFn = function(const Ctx: Pointer;
    const ACallNode: TGreenNode; out AExprKind: TSemanticHirExprKind;
    out AReceiverVarName, ACalleeName, AParamKinds: string;
    out ASlotIndex, AReturnTypeId: LongInt): Boolean;
  TTryGetOrdinaryMemberCallContractFn = function(const Ctx: Pointer;
    const ACallNode: TGreenNode; out AReceiverVarName, ACalleeName,
    AParamKinds: string; out AResultTypeId: LongInt): Boolean;
  TTryGetTypeCastTargetTypeIdFn = function(const Ctx: Pointer;
    const ACallNode: TGreenNode; out ATypeId: LongInt): Boolean;
  TTryGetIntrinsicExprNameFn = function(const Ctx: Pointer;
    const ACallNode: TGreenNode; out AIntrinsicName: string): Boolean;
  TResolveTypeIdForOwnerFn = function(const Ctx: Pointer; const ATypeName,
    AOwnerUnitId: string): LongInt;
  TEncodeRuntimeIntExprFoldFn = function(const Ctx: Pointer;
    const ANode: TGreenNode; out ABlob: string): Boolean;
  TCanEmitStrCompareOperandFn = function(const Ctx: Pointer;
    const ANode: TGreenNode; AAllowOwned: Boolean): Boolean;
  TEmitStrCompareOperandFn = function(const Ctx: Pointer;
    const ANode: TGreenNode; AAllowOwned: Boolean;
    out ABlob: string): Boolean;
  TTypeMetaIsInterfaceFn = function(const Ctx: Pointer; const ATypeName: string): Boolean;
  TTypeMetaInterfacesFn = function(const Ctx: Pointer; const ATypeName: string): string;
  TTypeMetaFieldIndexFn = function(const Ctx: Pointer; const ATypeName, AFieldName: string): Int64;

  { HIR 降级上下文 }
  TSemaHirLoweringContext = record
    { 数据成员 }
    Model: TSemanticModel;
    UnitGraph: TUnitGraph;
    RootAst: TAstFacade;
    CurrentProcessingUnitId: string;
    CurrentScopeId: LongInt;
    ProcedureBodies: TProcedureBodyVec;
    ImportedUnitOwners: TSemaImportedOwnerVec;
    ImportedUnitTrees: TSemaImportedTreeVec;
    BuiltinRegistry: TBuiltinRegistry;
    HirModule: THIRModule;
    Diagnostics: TDiagnosticsSink;
    RootFileId: TSourceFileId;
    BlockLabelCounter: LongInt;
    CurrentMethodClass: string;
    CurrentRetVarName: string;
    RuntimeVars: TSemaRuntimeVarRegistry;
    CurrentBlockTerminated: Boolean;
    { 回调 — 尚未提取到独立模块的方法 }
    CallbackCtx: Pointer;
    BuildTargetAddressExpr: TBuildTargetAddressExprFn;
    BuildClassBaseAddressExpr: TBuildClassBaseAddressExprFn;
    BuildByRefArgumentAddressExpr: TBuildByRefArgumentAddressExprFn;
    BuildRuntimeArrayElementAddressHirExpr: TBuildRuntimeArrayElementAddressHirExprFn;
    EvaluateIntegerConstant: TEvaluateIntegerConstantFn;
    InferExpressionType: TInferExpressionTypeFn;
    TypeIdForVariable: TTypeIdForVariableFn;
    TryGetDirectCallContract: TTryGetDirectCallContractFn;
    TryGetDispatchedMemberCallContract: TTryGetDispatchedMemberCallContractFn;
    TryGetOrdinaryMemberCallContract: TTryGetOrdinaryMemberCallContractFn;
    TryGetTypeCastTargetTypeId: TTryGetTypeCastTargetTypeIdFn;
    TryGetIntrinsicExprName: TTryGetIntrinsicExprNameFn;
    ResolveTypeIdForOwner: TResolveTypeIdForOwnerFn;
    EncodeRuntimeIntExprFold: TEncodeRuntimeIntExprFoldFn;
    CanEmitStrCompareOperand: TCanEmitStrCompareOperandFn;
    EmitStrCompareOperand: TEmitStrCompareOperandFn;
    TypeMetaIsInterface: TTypeMetaIsInterfaceFn;
    TypeMetaInterfaces: TTypeMetaInterfacesFn;
    TypeMetaFieldIndex: TTypeMetaFieldIndexFn;
  end;

{ 标签发射 }
procedure EmitBlockLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);
procedure EmitGotoLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);

{ 运行时表达式附着 }
procedure AttachRuntimeReturnExpr(const Ctx: TSemaHirLoweringContext;
  const AHirNodeId: LongInt; const AReturnVarName: string);

{ 诊断发射 }
procedure EmitSemaError(const Ctx: TSemaHirLoweringContext;
  const ACode: string; const AMessage: string; const AByteOffset: LongInt);

{ AST→HIR 布尔表达式折叠 }
function EncodeRuntimeBoolExprFold(const Ctx: TSemaHirLoweringContext;
  const ANode: TGreenNode; out ABlob: string;
  const AAllowOwnedStringCompare: Boolean): Boolean;

{ AST→HIR 表达式降级 }
function BuildRuntimeScalarHirExpr(const Ctx: TSemaHirLoweringContext;
  const ANode: TGreenNode; out AExprId: LongInt): Boolean;

{ 运行时变量查询 }
function HirLowering_IsRuntimeStrVar(const Ctx: TSemaHirLoweringContext;
  const AName: string): Boolean;

implementation

uses
  nextpas.compiler.sema.type_check,
  np_base_types;

{ === 标签发射 === }

{--- inlined nextpas.compiler.ir.hir.lowering_helpers.inc ---}
procedure EmitBlockLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);
begin
  Ctx.Model.AddTypedHirNode('block-label-runtime', ALabel, 0, 0, ALabel);
  Ctx.CurrentBlockTerminated := False;
end;

procedure EmitGotoLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);
begin
  if Ctx.CurrentBlockTerminated then
    Exit;
  Ctx.Model.AddTypedHirNode('br-runtime', ALabel, 0, 0, ALabel);
  Ctx.CurrentBlockTerminated := True;
end;

{ === 运行时表达式附着 === }

procedure AttachRuntimeReturnExpr(const Ctx: TSemaHirLoweringContext;
  const AHirNodeId: LongInt; const AReturnVarName: string);
var
  Children: array of LongInt;
  ExprId, SymbolId: LongInt;
begin
  if (AHirNodeId <= 0) or (AReturnVarName = '') then
    Exit;
  SymbolId := Ctx.Model.FindSymbolByName(AReturnVarName);
  if SymbolId <= 0 then
    Exit;
  SetLength(Children, 0);
  ExprId := Ctx.Model.AddHirExpr(
    shekSymbolValue, 0,
    SymbolId, Children, 0, 0.0, '', '', 0, shvcScalar
  );
  Ctx.Model.SetTypedHirNodeExprId(AHirNodeId, ExprId);
end;

{ === 诊断发射 === }

procedure EmitSemaError(const Ctx: TSemaHirLoweringContext;
  const ACode: string; const AMessage: string; const AByteOffset: LongInt);
var
  EmptyPayload: TDiagnosticPayload;
begin
  EmptyPayload.Kind := dpkNone;
  Ctx.Diagnostics.EmitErrorWithPayload(
    ACode, 'sema',
    BuildCoreSourceSpan(Ctx.RootFileId, AByteOffset, 0),
    AMessage, EmptyPayload);
end;

{ === 运行时变量查询 === }

function HirLowering_IsRuntimeStrVar(const Ctx: TSemaHirLoweringContext;
  const AName: string): Boolean;
var
  SymId: LongInt;
  TypeId: LongInt;
  TypeName: string;
begin
  if Ctx.RuntimeVars.IsRuntimeStrVar(AName) then
    Exit(True);
  SymId := Ctx.Model.FindSymbolByName(AName);
  if SymId > 0 then
  begin
    TypeId := Ctx.Model.SymbolAt(SymId - 1).TypeId;
    if TypeId > 0 then
    begin
      TypeName := Ctx.Model.TypeAt(TypeId - 1).Name;
      if SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString') then
        Exit(True);
    end;
  end;
  Result := False;
end;

{ === AST→HIR 表达式降级 (BuildRuntimeScalarHirExpr) === }

{--- end ---}

{--- inlined nextpas.compiler.ir.hir.lowering_scalar.inc ---}
function BuildRuntimeScalarHirExpr(const Ctx: TSemaHirLoweringContext; const ANode: TGreenNode;
  out AExprId: LongInt): Boolean;
var
  Children: array of LongInt;
  LeftExprId, RightExprId, SymbolId: LongInt;
  LeftTypeId, RightTypeId, ResultTypeId, BoolTypeId: LongInt;
  ArgExprId, ArgIndex, SlotIndex: LongInt;
  Value: Int64;
  ParseCode: Word;
  Op, Pred, CalleeName, ParamKinds, ReceiverVarName: string;
  DispatchExprKind: TSemanticHirExprKind;
  CallNode: TGreenNode;

  function ExprTypeId(const ALocalExprId: LongInt): LongInt;
  var
    Expr: TSemanticHirExpr;
  begin
    if (ALocalExprId <= 0) or (ALocalExprId > Ctx.Model.HirExprCount) then
      Exit(0);
    Expr := Ctx.Model.HirExprAt(ALocalExprId - 1);
    Result := Expr.TypeId;
  end;

  function FindScalarTypeId(const AKind: TSemanticScalarKind;
    const ABitWidth: LongInt; const ASigned: Boolean): LongInt;
  var
    I: LongInt;
    Fact: TSemanticScalarTypeFact;
  begin
    for I := 0 to Ctx.Model.TypeCount - 1 do
    begin
      if Ctx.Model.GetTypeScalarFact(I + 1, Fact) and
        (Fact.Kind = AKind) and (Fact.BitWidth = ABitWidth) and
        (Fact.Signed = ASigned) then
        Exit(I + 1);
    end;
    Result := 0;
  end;

  function NextSignedWidth(const ABitWidth: LongInt): LongInt;
  begin
    if ABitWidth < 32 then
      Result := 32
    else if ABitWidth < 64 then
      Result := 64
    else
      Result := 0;
  end;

  function CommonIntegerTypeId(const ALeftTypeId,
    ARightTypeId: LongInt): LongInt;
  var
    LeftFact, RightFact: TSemanticScalarTypeFact;
    MaxWidth, CommonWidth: LongInt;
    CommonSigned: Boolean;
  begin
    Result := 0;
    if (ALeftTypeId <= 0) or (ARightTypeId <= 0) then
      Exit;
    if ALeftTypeId = ARightTypeId then
      Exit(ALeftTypeId);
    if (not Ctx.Model.GetTypeScalarFact(ALeftTypeId, LeftFact)) or
      (not Ctx.Model.GetTypeScalarFact(ARightTypeId, RightFact)) then
      Exit;
    if (LeftFact.Kind <> sskInt) or (RightFact.Kind <> sskInt) then
      Exit;

    MaxWidth := LeftFact.BitWidth;
    if RightFact.BitWidth > MaxWidth then
      MaxWidth := RightFact.BitWidth;

    if LeftFact.Signed = RightFact.Signed then
      Exit(FindScalarTypeId(sskInt, MaxWidth, LeftFact.Signed));

    CommonSigned := True;
    if LeftFact.Signed and (LeftFact.BitWidth > RightFact.BitWidth) then
      CommonWidth := LeftFact.BitWidth
    else if RightFact.Signed and (RightFact.BitWidth > LeftFact.BitWidth) then
      CommonWidth := RightFact.BitWidth
    else
      CommonWidth := NextSignedWidth(MaxWidth);

    if CommonWidth = 0 then
      Exit(0);
    Result := FindScalarTypeId(sskInt, CommonWidth, CommonSigned);
  end;

  function CastExprToType(const ALocalExprId,
    ATargetTypeId: LongInt): LongInt;
  var
    LocalChildren: array of LongInt;
    LocalTypeId: LongInt;
  begin
    Result := 0;
    LocalTypeId := ExprTypeId(ALocalExprId);
    if (ALocalExprId <= 0) or (LocalTypeId <= 0) or (ATargetTypeId <= 0) then
      Exit;
    if LocalTypeId = ATargetTypeId then
      Exit(ALocalExprId);
    SetLength(LocalChildren, 1);
    LocalChildren[0] := ALocalExprId;
    Result := Ctx.Model.AddHirExpr(
      shekCast, ATargetTypeId, 0,
    LocalChildren, 0, 0.0, '', '', 0, shvcScalar
    );
  end;

  function IsStructuredAddressableScalarType(const ATypeId: LongInt): Boolean;
  var
    Fact: TSemanticScalarTypeFact;
  begin
    if ATypeId <= 0 then
      Exit(False);
    if not Ctx.Model.GetTypeScalarFact(ATypeId, Fact) then
      Exit(False);
    Result := Fact.Kind in [sskBool, sskInt, sskFloat, sskPointer];
  end;

  function AddRuntimePointerSymbolValueExpr(const ASymbolName: string;
    out ALocalExprId: LongInt): Boolean;
  var
    LocalChildren: array of LongInt;
    LocalSymbolId, PointerTypeId: LongInt;
  begin
    ALocalExprId := 0;
    if (ASymbolName = '') or (not Ctx.RuntimeVars.IsRuntimeVar(ASymbolName)) then
      Exit(False);
    LocalSymbolId := Ctx.Model.FindSymbolByName(ASymbolName);
    if LocalSymbolId <= 0 then
      Exit(False);
    PointerTypeId := Ctx.Model.FindTypeByName('Pointer');
    if PointerTypeId <= 0 then
      Exit(False);
    SetLength(LocalChildren, 0);
    ALocalExprId := Ctx.Model.AddHirExpr(
      shekSymbolValue, PointerTypeId, LocalSymbolId, LocalChildren,
      0,
    0.0, '', '', 0, shvcScalar
    );
    Result := True;
  end;

  function BuildRuntimeMemberReceiverExpr(const AReceiverName: string;
    out ALocalExprId: LongInt): Boolean;
  var
    ClassTypeId: LongInt;
    ClassTypeName: string;
  begin
    ALocalExprId := 0;
    if SameText(AReceiverName, 'self') and (Ctx.CurrentMethodClass <> '') then
      Exit(Ctx.BuildClassBaseAddressExpr(Ctx.CallbackCtx, 'self', Ctx.CurrentMethodClass, ALocalExprId));
    ClassTypeId := Ctx.TypeIdForVariable(Ctx.CallbackCtx, AReceiverName);
    if (ClassTypeId > 0) and (ClassTypeId <= Ctx.Model.TypeCount) then
    begin
      ClassTypeName := Ctx.Model.TypeAt(ClassTypeId - 1).Name;
      if ClassTypeName <> '' then
        Exit(Ctx.BuildClassBaseAddressExpr(Ctx.CallbackCtx, AReceiverName, ClassTypeName, ALocalExprId));
    end;
    ClassTypeName := Ctx.RuntimeVars.LookupClassVar(AReceiverName);
    if ClassTypeName <> '' then
      Exit(Ctx.BuildClassBaseAddressExpr(Ctx.CallbackCtx, AReceiverName, ClassTypeName, ALocalExprId));
    Result := AddRuntimePointerSymbolValueExpr(AReceiverName, ALocalExprId);
  end;

  function TryRuntimePointerFieldNode(const ALocalNode: TGreenNode;
    out APointerName, APointeeTypeName, AFieldName: string;
    out AFieldMeta: TFieldMeta): Boolean;
  var
    BaseNode, DerefNode, FieldNode: TGreenNode;
    Meta: TTypeMetadata;
    I: LongInt;
  begin
    APointerName := '';
    APointeeTypeName := '';
    AFieldName := '';
    AFieldMeta.Name := '';
    AFieldMeta.Index := 0;
    AFieldMeta.IsString := False;
    AFieldMeta.IsPointer := False;
    AFieldMeta.TypeId := 0;
    if (ALocalNode = nil) or (ALocalNode.NodeKind <> gnkDotAccess) or
      (ALocalNode.ChildCount < 2) then
      Exit(False);
    DerefNode := ALocalNode.ChildAt(0);
    FieldNode := ALocalNode.ChildAt(1);
    if (DerefNode = nil) or (DerefNode.NodeKind <> gnkDereference) or
      (DerefNode.ChildCount < 1) or (FieldNode = nil) or
      (FieldNode.NodeKind <> gnkIdentifier) then
      Exit(False);
    BaseNode := DerefNode.ChildAt(0);
    if (BaseNode = nil) or (BaseNode.NodeKind <> gnkIdentifier) then
      Exit(False);
    APointerName := BaseNode.Text;
    APointeeTypeName := Ctx.RuntimeVars.LookupPointerVar(APointerName);
    if APointeeTypeName = '' then
      Exit(False);
    AFieldName := FieldNode.Text;
    if not Ctx.Model.GetTypeMetaByName(APointeeTypeName, Meta) then
      Exit(False);
    if Meta.Fields <> nil then
      for I := 0 to LongInt(Meta.Fields.Count) - 1 do
        if SameText(Meta.Fields[SizeUInt(I)].Name, AFieldName) then
        begin
          AFieldMeta := Meta.Fields[SizeUInt(I)];
          Exit(AFieldMeta.TypeId > 0);
        end;
    Result := False;
  end;

  function BuildRuntimePointerFieldAddressHirExpr(
    const ALocalNode: TGreenNode; out ALocalExprId: LongInt): Boolean;
  var
    LocalChildren: array of LongInt;
    FieldExprId, PointeeTypeId, PointerExprId, PointerSymbolId: LongInt;
    PointerTypeId: LongInt;
    FieldMeta: TFieldMeta;
    FieldName, PointerName, PointeeTypeName: string;
  begin
    ALocalExprId := 0;
    if not TryRuntimePointerFieldNode(ALocalNode, PointerName, PointeeTypeName,
      FieldName, FieldMeta) then
      Exit(False);
    PointerSymbolId := Ctx.Model.FindSymbolByName(PointerName);
    PointerTypeId := Ctx.Model.FindTypeByName('Pointer');
    PointeeTypeId := Ctx.Model.FindTypeByName(PointeeTypeName);
    if (PointerSymbolId <= 0) or (PointerTypeId <= 0) or
      (PointeeTypeId <= 0) then
      Exit(False);

    SetLength(LocalChildren, 0);
    PointerExprId := Ctx.Model.AddHirExpr(
      shekSymbolValue, PointerTypeId, PointerSymbolId, LocalChildren,
      0,
    0.0, '', '', 0, shvcScalar
    );

    SetLength(LocalChildren, 1);
    LocalChildren[0] := PointerExprId;
    FieldExprId := Ctx.Model.AddHirExpr(
      shekDeref, PointeeTypeId, 0,
    LocalChildren, 0, 0.0, '', '', 0, shvcAddress
    );

    SetLength(LocalChildren, 1);
    LocalChildren[0] := FieldExprId;
    ALocalExprId := Ctx.Model.AddHirExpr(
      shekField, FieldMeta.TypeId, 0,
    LocalChildren, FieldMeta.Index, 0.0,
      FieldName, '', 0, shvcAddress
    );
    Result := ALocalExprId > 0;
  end;

  function BuildRuntimePointerHirExpr(const ALocalNode: TGreenNode;
    out ALocalExprId: LongInt): Boolean;
  var
    LocalExpr: TSemanticHirExpr;
  begin
    ALocalExprId := 0;
    if ALocalNode = nil then
      Exit(False);

    if ALocalNode.NodeKind = gnkIdentifier then
      Exit(AddRuntimePointerSymbolValueExpr(ALocalNode.Text, ALocalExprId));

    if not BuildRuntimeScalarHirExpr(Ctx, ALocalNode, ALocalExprId) then
      Exit(False);
    if (ALocalExprId <= 0) or (ALocalExprId > Ctx.Model.HirExprCount) then
      Exit(False);
    LocalExpr := Ctx.Model.HirExprAt(ALocalExprId - 1);
    Result := (LocalExpr.TypeId = Ctx.Model.FindTypeByName('Pointer')) and
      (LocalExpr.ValueClass = shvcScalar);
  end;

  function HasArrayBackedBase(const ALocalNode: TGreenNode): Boolean;
  begin
    if ALocalNode = nil then
      Exit(False);
    case ALocalNode.NodeKind of
      gnkArrayAccess:
        Exit(True);
      gnkDotAccess:
        begin
          if ALocalNode.ChildCount < 1 then
            Exit(False);
          Exit(HasArrayBackedBase(ALocalNode.ChildAt(0)));
        end;
    end;
    Result := False;
  end;

  function TryBuildStructuredAddressBackedValueExpr(
    const ALocalNode: TGreenNode; out ALocalExprId: LongInt): Boolean;
  var
    LocalTypeId: LongInt;
  begin
    ALocalExprId := 0;
    if not Ctx.BuildTargetAddressExpr(Ctx.CallbackCtx, ALocalNode, ALocalExprId) then
      Exit(False);
    LocalTypeId := ExprTypeId(ALocalExprId);
    if not IsStructuredAddressableScalarType(LocalTypeId) then
    begin
      ALocalExprId := 0;
      Exit(False);
    end;
    Result := True;
  end;

  function TryBuildTypeCastHirExpr(
    const ALocalCallNode: TGreenNode; out ALocalExprId: LongInt): Boolean;
  var
    SourceExprId, SourceTypeId, TargetTypeId: LongInt;
  begin
    ALocalExprId := 0;
    if not Ctx.TryGetTypeCastTargetTypeId(Ctx.CallbackCtx, ALocalCallNode, TargetTypeId) then
      Exit(False);
    if (ALocalCallNode.ChildCount < 2) or (ALocalCallNode.ChildAt(1) = nil) then
      Exit(False);
    if not BuildRuntimeScalarHirExpr(Ctx, ALocalCallNode.ChildAt(1), SourceExprId) then
      Exit(False);
    SourceTypeId := ExprTypeId(SourceExprId);
    if (SourceTypeId <= 0) or (TargetTypeId <= 0) then
      Exit(False);
    if not IsStructuredAddressableScalarType(SourceTypeId) or
      not IsStructuredAddressableScalarType(TargetTypeId) then
      Exit(False);
    ALocalExprId := CastExprToType(SourceExprId, TargetTypeId);
    Result := ALocalExprId > 0;
  end;

  function TryBuildIntrinsicHirExpr(
    const ALocalCallNode: TGreenNode; out ALocalExprId: LongInt): Boolean;
  var
    IntrinsicName: string;
    ArgNode: TGreenNode;
    ArgTypeId, DefaultTypeId, LiteralTypeId, OperandExprId, ResultTypeId: LongInt;
  begin
    ALocalExprId := 0;
    if not Ctx.TryGetIntrinsicExprName(Ctx.CallbackCtx, ALocalCallNode, IntrinsicName) then
      Exit(False);

    if SameText(IntrinsicName, 'Default') then
    begin
      if (ALocalCallNode.ChildCount < 2) or (ALocalCallNode.ChildAt(1) = nil) then
        Exit(False);
      ArgNode := ALocalCallNode.ChildAt(1);
      DefaultTypeId := 0;
      if ArgNode.NodeKind = gnkIdentifier then
      begin
        DefaultTypeId := Ctx.ResolveTypeIdForOwner(Ctx.CallbackCtx, ArgNode.Text,
          NormalizeUnitIdentity(Ctx.CurrentProcessingUnitId)
        );
        if DefaultTypeId <= 0 then
          DefaultTypeId := Ctx.ResolveTypeIdForOwner(Ctx.CallbackCtx, ArgNode.Text,
            NormalizeUnitIdentity(Ctx.UnitGraph.RootName)
          );
      end;
      if DefaultTypeId <= 0 then
        DefaultTypeId := Ctx.InferExpressionType(Ctx.CallbackCtx, ArgNode);
      if (DefaultTypeId > 0) and (Ctx.Model.FindTypeByName('Pointer') = DefaultTypeId) then
      begin
        SetLength(Children, 0);
        ALocalExprId := Ctx.Model.AddHirExpr(
          shekNilLiteral, DefaultTypeId, 0,
    Children, 0, 0.0,
          '', '', ALocalCallNode.ByteOffset, shvcScalar
        );
        Exit(ALocalExprId > 0);
      end;
    end;

    if Ctx.EvaluateIntegerConstant(Ctx.CallbackCtx, ALocalCallNode, Value) then
    begin
      LiteralTypeId := Ctx.InferExpressionType(Ctx.CallbackCtx, ALocalCallNode);
      if LiteralTypeId <= 0 then
        LiteralTypeId := Ctx.Model.FindTypeByName('Integer');
      SetLength(Children, 0);
      ALocalExprId := Ctx.Model.AddHirExpr(
        shekIntLiteral, LiteralTypeId, 0,
    Children, Value, 0.0,
        '', '', ALocalCallNode.ByteOffset, shvcScalar
      );
      Exit(ALocalExprId > 0);
    end;

    if (ALocalCallNode.ChildCount < 2) or (ALocalCallNode.ChildAt(1) = nil) then
      Exit(False);
    if not BuildRuntimeScalarHirExpr(Ctx, ALocalCallNode.ChildAt(1), OperandExprId) then
      Exit(False);
    ArgTypeId := ExprTypeId(OperandExprId);
    if ArgTypeId <= 0 then
      Exit(False);

    if SameText(IntrinsicName, 'Ord') then
    begin
      ResultTypeId := Ctx.Model.FindTypeByName('Integer');
      ALocalExprId := CastExprToType(OperandExprId, ResultTypeId);
      Exit(ALocalExprId > 0);
    end;

    if SameText(IntrinsicName, 'Chr') then
    begin
      ResultTypeId := Ctx.Model.FindTypeByName('Char');
      ALocalExprId := CastExprToType(OperandExprId, ResultTypeId);
      Exit(ALocalExprId > 0);
    end;

    if SameText(IntrinsicName, 'Pred') or SameText(IntrinsicName, 'Succ') then
    begin
      ResultTypeId := Ctx.InferExpressionType(Ctx.CallbackCtx, ALocalCallNode);
      if ResultTypeId <= 0 then
        ResultTypeId := ArgTypeId;
      SetLength(Children, 0);
      LeftExprId := Ctx.Model.AddHirExpr(
        shekIntLiteral, ResultTypeId, 0,
    Children, 1, 0.0,
        '', '', ALocalCallNode.ByteOffset, shvcScalar
      );
      if LeftExprId <= 0 then
        Exit(False);
      OperandExprId := CastExprToType(OperandExprId, ResultTypeId);
      if OperandExprId <= 0 then
        Exit(False);
      SetLength(Children, 2);
      Children[0] := OperandExprId;
      Children[1] := LeftExprId;
      if SameText(IntrinsicName, 'Pred') then
        Op := '-'
      else
        Op := '+';
      ALocalExprId := Ctx.Model.AddHirExpr(
        shekBinaryOp, ResultTypeId, 0,
    Children, 0, 0.0,
        '', Op, ALocalCallNode.ByteOffset, shvcScalar
      );
      Exit(ALocalExprId > 0);
    end;

    Result := False;
  end;
begin
  AExprId := 0;
  if ANode = nil then
    Exit(False);

  CallNode := ANode;
  if (CallNode.NodeKind = gnkProcedureCallStatement) and
    (CallNode.ChildCount >= 1) and (CallNode.ChildAt(0) <> nil) and
    (CallNode.ChildAt(0).NodeKind = gnkFunctionCall) then
    CallNode := CallNode.ChildAt(0);

  if (CallNode.NodeKind = gnkFunctionCall) and
    (SameText(CallNode.Text, 'Length') or
     ((CallNode.ChildCount >= 1) and (CallNode.ChildAt(0) <> nil) and
      (CallNode.ChildAt(0).NodeKind = gnkIdentifier) and
      SameText(CallNode.ChildAt(0).Text, 'Length'))) then
    Exit(False);

  if ANode.NodeKind = gnkIntegerLiteral then
  begin
    Val(ANode.Text, Value, ParseCode);
    if ParseCode <> 0 then
      Exit(False);
    SetLength(Children, 0);
    AExprId := Ctx.Model.AddHirExpr(
      shekIntLiteral, Ctx.Model.FindTypeByName('Integer'), 0,
    Children, Value, 0.0,
      '', '', 0, shvcScalar
    );
    Exit(True);
  end;

  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'True') then
  begin
    SetLength(Children, 0);
    AExprId := Ctx.Model.AddHirExpr(
      shekIntLiteral, Ctx.Model.FindTypeByName('Boolean'), 0,
    Children, 1, 0.0,
      '', '', 0, shvcScalar
    );
    Exit(True);
  end;

  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'False') then
  begin
    SetLength(Children, 0);
    AExprId := Ctx.Model.AddHirExpr(
      shekIntLiteral, Ctx.Model.FindTypeByName('Boolean'), 0,
    Children, 0, 0.0,
      '', '', 0, shvcScalar
    );
    Exit(True);
  end;

  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Assigned') and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    LeftTypeId := Ctx.Model.FindTypeByName('Pointer');
    BoolTypeId := Ctx.Model.FindTypeByName('Boolean');
    if (LeftTypeId <= 0) or (BoolTypeId <= 0) then
      Exit(False);
    SymbolId := Ctx.Model.FindSymbolByName(ANode.ChildAt(1).Text);
    if SymbolId <= 0 then
      Exit(False);
    SetLength(Children, 0);
    LeftExprId := Ctx.Model.AddHirExpr(
      shekSymbolValue, LeftTypeId, SymbolId, Children,
      0,
    0.0, '', '', ANode.ChildAt(1).ByteOffset, shvcScalar
    );
    if LeftExprId <= 0 then
      Exit(False);
    SetLength(Children, 0);
    RightExprId := Ctx.Model.AddHirExpr(
      shekNilLiteral, LeftTypeId, 0,
    Children, 0, 0.0,
      '', '', 0, shvcScalar
    );
    if RightExprId <= 0 then
      Exit(False);
    SetLength(Children, 2);
    Children[0] := LeftExprId;
    Children[1] := RightExprId;
    AExprId := Ctx.Model.AddHirExpr(
      shekCompareOp, BoolTypeId, 0,
    Children, 0, 0.0,
      '', 'ne', ANode.ByteOffset, shvcScalar
    );
    Exit(AExprId > 0);
  end;

  if (ANode.NodeKind = gnkIdentifier) and
    Ctx.Model.LookupConstValue(ANode.Text, Value) then
  begin
    SetLength(Children, 0);
    AExprId := Ctx.Model.AddHirExpr(
      shekIntLiteral, Ctx.Model.FindTypeByName('Integer'), 0,
    Children, Value, 0.0,
      '', '', 0, shvcScalar
    );
    Exit(True);
  end;

  if (ANode.NodeKind = gnkIdentifier) and Ctx.RuntimeVars.IsRuntimeVar(ANode.Text) then
  begin
    SymbolId := Ctx.Model.FindSymbolByName(ANode.Text);
    if SymbolId <= 0 then
      Exit(False);
    SetLength(Children, 0);
    AExprId := Ctx.Model.AddHirExpr(
      shekSymbolValue, Ctx.Model.SymbolTypeId(SymbolId), SymbolId, Children,
      0,
    0.0, '', '', 0, shvcScalar
    );
    Exit(True);
  end;

  if (CallNode.NodeKind = gnkFunctionCall) and
    TryBuildTypeCastHirExpr(CallNode, AExprId) then
    Exit(True);

  if (CallNode.NodeKind = gnkFunctionCall) and
    TryBuildIntrinsicHirExpr(CallNode, AExprId) then
    Exit(True);

  if Ctx.TryGetDispatchedMemberCallContract(Ctx.CallbackCtx, ANode, DispatchExprKind,
    ReceiverVarName, CalleeName, ParamKinds, SlotIndex, ResultTypeId) then
  begin
    if not IsStructuredAddressableScalarType(ResultTypeId) then
      Exit(False);
    SetLength(Children, Length(ParamKinds));
    if not BuildRuntimeMemberReceiverExpr(ReceiverVarName, ArgExprId) then
      Exit(False);
    Children[0] := ArgExprId;
    for ArgIndex := 2 to Length(ParamKinds) do
    begin
      case ParamKinds[ArgIndex] of
        'p':
          begin
            if not BuildRuntimePointerHirExpr(ANode.ChildAt(ArgIndex - 1),
              ArgExprId) then
              Exit(False);
          end;
        'r':
          begin
            if not Ctx.BuildByRefArgumentAddressExpr(Ctx.CallbackCtx, CallNode.ChildAt(ArgIndex - 1),
              ArgExprId) then
              Exit(False);
          end;
        'i':
          begin
            if not BuildRuntimeScalarHirExpr(Ctx, CallNode.ChildAt(ArgIndex - 1),
              ArgExprId) then
              Exit(False);
          end;
      else
        Exit(False);
      end;
      Children[ArgIndex - 1] := ArgExprId;
    end;
    AExprId := Ctx.Model.AddHirExpr(
      DispatchExprKind, ResultTypeId, 0,
    Children, SlotIndex, 0.0, CalleeName,
      ParamKinds, ANode.ByteOffset, shvcScalar
    );
    Exit(AExprId > 0);
  end;

  if Ctx.TryGetOrdinaryMemberCallContract(Ctx.CallbackCtx, ANode, ReceiverVarName, CalleeName,
    ParamKinds, ResultTypeId) then
  begin
    if not IsStructuredAddressableScalarType(ResultTypeId) then
      Exit(False);
    SetLength(Children, Length(ParamKinds));
    if not BuildRuntimeMemberReceiverExpr(ReceiverVarName, ArgExprId) then
      Exit(False);
    Children[0] := ArgExprId;
    for ArgIndex := 2 to Length(ParamKinds) do
    begin
      case ParamKinds[ArgIndex] of
        'p':
          begin
            if not BuildRuntimePointerHirExpr(ANode.ChildAt(ArgIndex - 1),
              ArgExprId) then
              Exit(False);
          end;
        'r':
          begin
            if not Ctx.BuildByRefArgumentAddressExpr(Ctx.CallbackCtx, CallNode.ChildAt(ArgIndex - 1),
              ArgExprId) then
              Exit(False);
          end;
        'i':
          begin
            if not BuildRuntimeScalarHirExpr(Ctx, CallNode.ChildAt(ArgIndex - 1),
              ArgExprId) then
              Exit(False);
          end;
      else
        Exit(False);
      end;
      Children[ArgIndex - 1] := ArgExprId;
    end;
    AExprId := Ctx.Model.AddHirExpr(
      shekCall, ResultTypeId, 0,
    Children, 0, 0.0, CalleeName, ParamKinds,
      ANode.ByteOffset, shvcScalar
    );
    Exit(AExprId > 0);
  end;

  if (CallNode.NodeKind = gnkFunctionCall) and
    Ctx.TryGetDirectCallContract(Ctx.CallbackCtx, ANode, CalleeName, ParamKinds, ResultTypeId) then
  begin
    if not IsStructuredAddressableScalarType(ResultTypeId) then
      Exit(False);
    SetLength(Children, Length(ParamKinds));
    for ArgIndex := 1 to CallNode.ChildCount - 1 do
    begin
      case ParamKinds[ArgIndex] of
        'p':
          begin
            if not BuildRuntimePointerHirExpr(CallNode.ChildAt(ArgIndex),
              ArgExprId) then
              Exit(False);
          end;
        'r':
          begin
            if not Ctx.BuildByRefArgumentAddressExpr(Ctx.CallbackCtx, CallNode.ChildAt(ArgIndex),
              ArgExprId) then
              Exit(False);
          end;
        'i':
          begin
            if not BuildRuntimeScalarHirExpr(Ctx, CallNode.ChildAt(ArgIndex),
              ArgExprId) then
              Exit(False);
          end;
      else
        Exit(False);
      end;
      Children[ArgIndex - 1] := ArgExprId;
    end;
    AExprId := Ctx.Model.AddHirExpr(
      shekCall, ResultTypeId, 0,
    Children, 0, 0.0, CalleeName, ParamKinds,
      ANode.ByteOffset, shvcScalar
    );
    Exit(AExprId > 0);
  end;

  if ANode.NodeKind = gnkArrayAccess then
    Exit(TryBuildStructuredAddressBackedValueExpr(ANode, AExprId));

  if (ANode.NodeKind = gnkUnaryExpression) and (ANode.ChildCount >= 1) and
    (ANode.Text = '@') then
  begin
    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkDotAccess) then
    begin
      if not BuildRuntimePointerFieldAddressHirExpr(ANode.ChildAt(0),
        LeftExprId) then
        Exit(False);
      SetLength(Children, 1);
      Children[0] := LeftExprId;
      AExprId := Ctx.Model.AddHirExpr(
        shekAddressOf, Ctx.Model.FindTypeByName('Pointer'), 0,
    Children, 0, 0.0,
        '', '', 0, shvcScalar
      );
      Exit(True);
    end;

    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkArrayAccess) then
    begin
      if not Ctx.BuildRuntimeArrayElementAddressHirExpr(Ctx.CallbackCtx, ANode.ChildAt(0),
        LeftExprId) then
        Exit(False);
      SetLength(Children, 1);
      Children[0] := LeftExprId;
      AExprId := Ctx.Model.AddHirExpr(
        shekAddressOf, Ctx.Model.FindTypeByName('Pointer'), 0,
    Children, 0, 0.0,
        '', '', 0, shvcScalar
      );
      Exit(True);
    end;

    if (ANode.ChildAt(0) = nil) or
      (ANode.ChildAt(0).NodeKind <> gnkIdentifier) then
      Exit(False);
    if not Ctx.RuntimeVars.IsRuntimeVar(ANode.ChildAt(0).Text) then
      Exit(False);
    SymbolId := Ctx.Model.FindSymbolByName(ANode.ChildAt(0).Text);
    if SymbolId <= 0 then
      Exit(False);
    ResultTypeId := Ctx.Model.SymbolTypeId(SymbolId);
    if not IsStructuredAddressableScalarType(ResultTypeId) then
      Exit(False);
    SetLength(Children, 0);
    LeftExprId := Ctx.Model.AddHirExpr(
      shekSymbolAddress, ResultTypeId, SymbolId, Children,
      0,
    0.0, '', '', 0, shvcAddress
    );
    SetLength(Children, 1);
    Children[0] := LeftExprId;
    AExprId := Ctx.Model.AddHirExpr(
      shekAddressOf, Ctx.Model.FindTypeByName('Pointer'), 0,
    Children, 0, 0.0,
      '', '', 0, shvcScalar
    );
    Exit(True);
  end;

  if (ANode.NodeKind = gnkDereference) and (ANode.ChildCount >= 1) then
  begin
    if not BuildRuntimePointerHirExpr(ANode.ChildAt(0), LeftExprId) then
      Exit(False);
    SetLength(Children, 1);
    Children[0] := LeftExprId;
    AExprId := Ctx.Model.AddHirExpr(
      shekDeref, Ctx.Model.FindTypeByName('Integer'), 0,
    Children, 0, 0.0,
      '', '', 0, shvcAddress
    );
    Exit(True);
  end;

  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) then
  begin
    if BuildRuntimePointerFieldAddressHirExpr(ANode, AExprId) then
      Exit(True);
    if HasArrayBackedBase(ANode.ChildAt(0)) and
      TryBuildStructuredAddressBackedValueExpr(ANode, AExprId) then
      Exit(True);
    Exit(False);
  end;

  if (ANode.NodeKind = gnkUnaryExpression) and (ANode.ChildCount >= 1) then
  begin
    if not BuildRuntimeScalarHirExpr(Ctx, ANode.ChildAt(0), LeftExprId) then
      Exit(False);
    if ANode.Text = '-' then
      Op := '-'
    else if SameText(ANode.Text, 'not') then
      Op := 'not'
    else
      Exit(False);
    SetLength(Children, 1);
    Children[0] := LeftExprId;
    ResultTypeId := ExprTypeId(LeftExprId);
    if ResultTypeId <= 0 then
      Exit(False);
    if SameText(Op, 'not') and
      (ResultTypeId <> Ctx.Model.FindTypeByName('Boolean')) then
      Exit(False);
    AExprId := Ctx.Model.AddHirExpr(
      shekUnaryOp, ResultTypeId, 0,
    Children, 0, 0.0, '', Op, 0, shvcScalar
    );
    Exit(True);
  end;

  if (ANode.NodeKind <> gnkBinaryExpression) or (ANode.ChildCount < 2) then
    Exit(False);

  Op := ANode.Text;
  if (Op = '+') or (Op = '-') or (Op = '*') or SameText(Op, 'div') or
    SameText(Op, 'mod') or SameText(Op, 'and') or SameText(Op, 'or') then
  begin
    if not BuildRuntimeScalarHirExpr(Ctx, ANode.ChildAt(0), LeftExprId) then
      Exit(False);
    if not BuildRuntimeScalarHirExpr(Ctx, ANode.ChildAt(1), RightExprId) then
      Exit(False);
    LeftTypeId := ExprTypeId(LeftExprId);
    RightTypeId := ExprTypeId(RightExprId);
    if SameText(Op, 'and') or SameText(Op, 'or') then
    begin
      ResultTypeId := Ctx.Model.FindTypeByName('Boolean');
      if (LeftTypeId <> ResultTypeId) or (RightTypeId <> ResultTypeId) then
        Exit(False);
    end
    else
    begin
      ResultTypeId := CommonIntegerTypeId(LeftTypeId, RightTypeId);
      if ResultTypeId <= 0 then
        Exit(False);
      LeftExprId := CastExprToType(LeftExprId, ResultTypeId);
      RightExprId := CastExprToType(RightExprId, ResultTypeId);
      if (LeftExprId <= 0) or (RightExprId <= 0) then
        Exit(False);
    end;
    SetLength(Children, 2);
    Children[0] := LeftExprId;
    Children[1] := RightExprId;
    AExprId := Ctx.Model.AddHirExpr(
      shekBinaryOp, ResultTypeId, 0,
    Children, 0, 0.0, '', Op, 0, shvcScalar
    );
    Exit(True);
  end;

  if Op = '=' then Pred := '='
  else if Op = '<>' then Pred := '<>'
  else if Op = '<' then Pred := '<'
  else if Op = '<=' then Pred := '<='
  else if Op = '>' then Pred := '>'
  else if Op = '>=' then Pred := '>='
  else
    Exit(False);

  if not BuildRuntimeScalarHirExpr(Ctx, ANode.ChildAt(0), LeftExprId) then
    Exit(False);
  if not BuildRuntimeScalarHirExpr(Ctx, ANode.ChildAt(1), RightExprId) then
    Exit(False);
  LeftTypeId := ExprTypeId(LeftExprId);
  RightTypeId := ExprTypeId(RightExprId);
  BoolTypeId := Ctx.Model.FindTypeByName('Boolean');
  if (LeftTypeId = BoolTypeId) and (RightTypeId = BoolTypeId) then
    ResultTypeId := BoolTypeId
  else
  begin
    ResultTypeId := CommonIntegerTypeId(LeftTypeId, RightTypeId);
    if ResultTypeId <= 0 then
      Exit(False);
    LeftExprId := CastExprToType(LeftExprId, ResultTypeId);
    RightExprId := CastExprToType(RightExprId, ResultTypeId);
    if (LeftExprId <= 0) or (RightExprId <= 0) then
      Exit(False);
  end;
  SetLength(Children, 2);
  Children[0] := LeftExprId;
  Children[1] := RightExprId;
  AExprId := Ctx.Model.AddHirExpr(
    shekCompareOp, BoolTypeId, 0,
    Children, 0, 0.0, '', Pred, 0, shvcScalar
  );
  Result := True;
end;



{ === AST→HIR 布尔表达式折叠 === }

{--- end ---}

{--- inlined nextpas.compiler.ir.hir.lowering_bool.inc ---}
function EncodeRuntimeBoolExprFold(const Ctx: TSemaHirLoweringContext;
  const ANode: TGreenNode; out ABlob: string;
  const AAllowOwnedStringCompare: Boolean): Boolean;
var
  LeftBlob, RightBlob, Op, Pred, RecTypeName: string;
  RecNode: TGreenNode;
  LeftIsNil, RightIsNil: Boolean;
  FieldIdx: Int64;
begin
  ABlob := '';
  if ANode = nil then
    Exit(False);
  if (ANode.NodeKind = gnkUnaryExpression) and
    SameText(ANode.Text, 'not') and (ANode.ChildCount >= 1) then
  begin
    if not EncodeRuntimeBoolExprFold(Ctx, ANode.ChildAt(0), LeftBlob,
      AAllowOwnedStringCompare) then
      Exit(False);
    ABlob := 'int 1' + #10 + LeftBlob + 'zext' + #10 + 'sub' + #10 +
      'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and Ctx.RuntimeVars.IsRuntimeVar(ANode.Text) then
  begin
    ABlob := 'var ' + ANode.Text + #10 + 'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'True') then
  begin
    ABlob := 'int 1' + #10 + 'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'False') then
  begin
    ABlob := 'int 0' + #10 + 'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) or
    ((ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2)) then
  begin
    if Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ANode, LeftBlob) then
    begin
      ABlob := LeftBlob + 'int 0' + #10 + 'cmp ne' + #10;
      Exit(True);
    end;
  end;
  if ANode.NodeKind <> gnkBinaryExpression then
    Exit(False);
  if ANode.ChildCount < 2 then
    Exit(False);
  Op := ANode.Text;
  if Op = '=' then Pred := 'eq'
  else if Op = '<>' then Pred := 'ne'
  else if Op = '<' then Pred := 'slt'
  else if Op = '<=' then Pred := 'sle'
  else if Op = '>' then Pred := 'sgt'
  else if Op = '>=' then Pred := 'sge'
  else if SameText(Op, 'and') then
  begin
    if not EncodeRuntimeBoolExprFold(Ctx, ANode.ChildAt(0), LeftBlob,
      AAllowOwnedStringCompare) then
      Exit(False);
    if not EncodeRuntimeBoolExprFold(Ctx, ANode.ChildAt(1), RightBlob,
      AAllowOwnedStringCompare) then
      Exit(False);
    ABlob := LeftBlob + 'zext' + #10 + RightBlob + 'zext' + #10 +
      'mul' + #10 + 'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end
  else if SameText(Op, 'or') then
  begin
    if not EncodeRuntimeBoolExprFold(Ctx, ANode.ChildAt(0), LeftBlob,
      AAllowOwnedStringCompare) then
      Exit(False);
    if not EncodeRuntimeBoolExprFold(Ctx, ANode.ChildAt(1), RightBlob,
      AAllowOwnedStringCompare) then
      Exit(False);
    ABlob := LeftBlob + 'zext' + #10 + RightBlob + 'zext' + #10 +
      'add' + #10 + 'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end
  else if SameText(Op, 'is') then
  begin
    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
      (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
    begin
      if nextpas.compiler.sema.type_check.TypeMetaIsInterface(Ctx.Model, ANode.ChildAt(1).Text) then
      begin
        if (Ctx.RuntimeVars.LookupClassVar(ANode.ChildAt(0).Text) <> '') and
          (Pos(ANode.ChildAt(1).Text,
            nextpas.compiler.sema.type_check.TypeMetaInterfaces(Ctx.Model,
              Ctx.RuntimeVars.LookupClassVar(ANode.ChildAt(0).Text))) > 0) then
          ABlob := 'int 1' + #10 + 'int 0' + #10 + 'cmp ne' + #10
        else
          ABlob := 'int 0' + #10 + 'int 0' + #10 + 'cmp ne' + #10;
        Exit(True);
      end;
      ABlob := 'var ' + ANode.ChildAt(0).Text + #10 +
        'is ' + ANode.ChildAt(1).Text + #10 +
        'int 0' + #10 + 'cmp ne' + #10;
      Exit(True);
    end;
    Exit(False);
  end
  else if SameText(Op, 'as') then
  begin
    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
      (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
      (nextpas.compiler.sema.type_check.TypeMetaIsInterface(Ctx.Model, ANode.ChildAt(1).Text)) then
    begin
      ABlob := 'var ' + ANode.ChildAt(0).Text + #10;
      Exit(True);
    end;
    Exit(False);
  end
  else
    Exit(False);
  if (Op = '=') or (Op = '<>') then
  begin
    if Ctx.CanEmitStrCompareOperand(Ctx.CallbackCtx, ANode.ChildAt(0),
      AAllowOwnedStringCompare) and
      Ctx.CanEmitStrCompareOperand(Ctx.CallbackCtx, ANode.ChildAt(1),
      AAllowOwnedStringCompare) then
    begin
      if Ctx.EmitStrCompareOperand(Ctx.CallbackCtx, ANode.ChildAt(0),
        AAllowOwnedStringCompare, LeftBlob) and
        Ctx.EmitStrCompareOperand(Ctx.CallbackCtx, ANode.ChildAt(1),
        AAllowOwnedStringCompare, RightBlob) then
      begin
        ABlob := LeftBlob + RightBlob + 'strcmp ' + Pred + #10 +
          'int 0' + #10 + 'cmp ne' + #10;
        Exit(True);
      end;
    end;

    { TGreenNode (and similar facade records): class operator =/<> nil means
      FIndex < 0 / FIndex >= 0. Residual recvar+null+cmp compares the buffer
      address (always non-null) and also emits invalid icmp i64/ptr. }
    LeftIsNil := (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
      SameText(ANode.ChildAt(0).Text, 'nil');
    RightIsNil := (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
      SameText(ANode.ChildAt(1).Text, 'nil');
    RecNode := nil;
    if RightIsNil and (not LeftIsNil) then
      RecNode := ANode.ChildAt(0)
    else if LeftIsNil and (not RightIsNil) then
      RecNode := ANode.ChildAt(1);
    if (RecNode <> nil) and (RecNode.NodeKind = gnkIdentifier) and
      Ctx.RuntimeVars.IsRecordVar(RecNode.Text) then
    begin
      RecTypeName := Ctx.RuntimeVars.LookupRecordVar(RecNode.Text);
      FieldIdx := -1;
      if RecTypeName <> '' then
      begin
        FieldIdx := nextpas.compiler.sema.type_check.TypeMetaFieldIndex(Ctx.Model,
          RecTypeName, 'FIndex');
        if FieldIdx < 0 then
          FieldIdx := nextpas.compiler.sema.type_check.TypeMetaFieldIndex(Ctx.Model,
            RecTypeName, 'Index');
      end;
      { Layout fallback: TGreenNode = (FOwner:ptr, FIndex:LongInt) → slot 1. }
      if (FieldIdx < 0) and
        ((RecTypeName = '') or SameText(RecTypeName, 'TGreenNode')) then
        FieldIdx := 1;
      if FieldIdx >= 0 then
      begin
        { = nil → FIndex < 0; <> nil → FIndex >= 0 }
        if Op = '=' then
          Pred := 'slt'
        else
          Pred := 'sge';
        ABlob := 'rload ' + RecNode.Text + ' ' + IntToStr(FieldIdx) + #10 +
          'int 0' + #10 + 'cmp ' + Pred + #10;
        Exit(True);
      end;
    end;
  end;
  if not Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ANode.ChildAt(0), LeftBlob) then
    Exit(False);
  if not Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ANode.ChildAt(1), RightBlob) then
    Exit(False);
  ABlob := LeftBlob + RightBlob + 'cmp ' + Pred + #10;
  Result := True;
end;


{--- end ---}
end.
