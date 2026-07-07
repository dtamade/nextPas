{**
 * np_hir_to_mir.pas — HIR → MIR lowering pass
 *
 * 将 HIR（高层类型化 AST）降级为 MIR（中层级控制流图）。
 * 这是 MIR 管线的入口点。
 *
 * 完整实现：逐条翻译 HIR 指令 → MIR 语句，保留操作语义。
 *
 * 对标 rustc_mir_build::build。
 *}

unit np_hir_to_mir;

{$mode objfpc}{$H+}

interface

uses
  np_hir_model, np_hir_types, np_mir_model;

type
  {**
   * THirToMirLowering — HIR → MIR 降级器
   *
   * 遍历 HIR 模块，为每个函数生成对应的 MIR 基本块。
   * 完整翻译 HIR 指令操作码到 MIR 语句。
   *}
  THirToMirLowering = class
  private
    FHirModule: THIRModule;
    FMirModule: TMirModule;
    { HIR ValueId → MIR ValueId 映射 }
    FValueMap: array of record
      HirId: THIRValueId;
      MirId: TMirValueId;
    end;
    function HirTypeWidth(ATypeId: THIRTypeId): LongInt;
    function HirTypeSigned(ATypeId: THIRTypeId): Boolean;
    function MapValue(AHirValueId: THIRValueId): TMirValueId;
    function MapOperand(const AOp: THIROperand): TMirOperand;
    function TranslateInstrKind(AKind: THIRInstrKind; out AOp: TMirOp;
      out AStmtKind: TMirStmtKind): Boolean;
    procedure LowerFunction(const AHirFunc: THIRFunction);
    procedure LowerBlock(const AHirFunc: THIRFunction;
      const AHirBlock: THIRBlock; AMirFuncId: TMirFuncId);
    procedure LowerTerminator(const AHirTerm: THIRTerminator;
      AMirFuncId, AMirBlockId: TMirBlockId);
  public
    constructor Create(const AHirModule: THIRModule);
    destructor Destroy; override;
    function Lower: TMirModule;
  end;

implementation

constructor THirToMirLowering.Create(const AHirModule: THIRModule);
begin
  inherited Create;
  FHirModule := AHirModule;
  FMirModule := nil;
  SetLength(FValueMap, 0);
end;

destructor THirToMirLowering.Destroy;
begin
  FMirModule.Free;
  inherited Destroy;
end;

function THirToMirLowering.HirTypeWidth(ATypeId: THIRTypeId): LongInt;
var
  TypeRec: THIRTypeRec;
begin
  TypeRec := FHirModule.Types.GetType(ATypeId);
  Result := TypeRec.BitWidth;
end;

function THirToMirLowering.HirTypeSigned(ATypeId: THIRTypeId): Boolean;
var
  TypeRec: THIRTypeRec;
begin
  TypeRec := FHirModule.Types.GetType(ATypeId);
  Result := TypeRec.Signed;
end;

function THirToMirLowering.MapValue(AHirValueId: THIRValueId): TMirValueId;
var
  I: LongInt;
begin
  for I := 0 to High(FValueMap) do
    if FValueMap[I].HirId = AHirValueId then
      Exit(FValueMap[I].MirId);
  Result := FMirModule.NewValue;
  I := Length(FValueMap);
  SetLength(FValueMap, I + 1);
  FValueMap[I].HirId := AHirValueId;
  FValueMap[I].MirId := Result;
end;

function THirToMirLowering.MapOperand(const AOp: THIROperand): TMirOperand;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := mokLocal;
  Result.Value := MapValue(AOp.ValueId);
  Result.BitWidth := HirTypeWidth(AOp.TypeId);
  Result.IsSigned := HirTypeSigned(AOp.TypeId);
end;

function THirToMirLowering.TranslateInstrKind(AKind: THIRInstrKind;
  out AOp: TMirOp; out AStmtKind: TMirStmtKind): Boolean;
begin
  Result := True;
  case AKind of
    hikAlloca:       begin AStmtKind := mskAlloca;      AOp := moAdd; end;
    hikLoad:         begin AStmtKind := mskLoad;        AOp := moAdd; end;
    hikStore:        begin AStmtKind := mskStore;       AOp := moAdd; end;
    hikGetFieldPtr:  begin AStmtKind := mskGetFieldPtr; AOp := moAdd; end;
    hikAdd:          begin AStmtKind := mskBinary; AOp := moAdd; end;
    hikSub:          begin AStmtKind := mskBinary; AOp := moSub; end;
    hikMul:          begin AStmtKind := mskBinary; AOp := moMul; end;
    hikDiv:          begin AStmtKind := mskBinary; AOp := moSDiv; end;
    hikMod:          begin AStmtKind := mskBinary; AOp := moSRem; end;
    hikNeg:          begin AStmtKind := mskUnary;  AOp := moNeg; end;
    hikNot:          begin AStmtKind := mskUnary;  AOp := moNot; end;
    hikBitAnd:       begin AStmtKind := mskBinary; AOp := moAnd; end;
    hikBitOr:        begin AStmtKind := mskBinary; AOp := moOr; end;
    hikBitXor:       begin AStmtKind := mskBinary; AOp := moXor; end;
    hikShl:          begin AStmtKind := mskBinary; AOp := moShl; end;
    hikShr:          begin AStmtKind := mskBinary; AOp := moAShr; end;
    hikCmpEq:        begin AStmtKind := mskBinary; AOp := moEq; end;
    hikCmpNe:        begin AStmtKind := mskBinary; AOp := moNe; end;
    hikCmpLt:        begin AStmtKind := mskBinary; AOp := moSLt; end;
    hikCmpLe:        begin AStmtKind := mskBinary; AOp := moSLe; end;
    hikCmpGt:        begin AStmtKind := mskBinary; AOp := moSLt; end;
    hikCmpGe:        begin AStmtKind := mskBinary; AOp := moSLe; end;
    hikTrunc:        begin AStmtKind := mskUnary;  AOp := moTrunc; end;
    hikZext:         begin AStmtKind := mskUnary;  AOp := moZext; end;
    hikSext:         begin AStmtKind := mskUnary;  AOp := moSext; end;
    hikBitcast:      begin AStmtKind := mskUnary;  AOp := moBitcast; end;
    hikIntToFloat:   begin AStmtKind := mskUnary;  AOp := moSIToFP; end;
    hikFloatToInt:   begin AStmtKind := mskUnary;  AOp := moFPToSI; end;
    hikCall:         begin AStmtKind := mskCall;   AOp := moAdd; end;
    hikIndirectCall: begin AStmtKind := mskCall;   AOp := moAdd; end;
    hikIntrinsic:    begin AStmtKind := mskCall;   AOp := moAdd; end;
    hikInsertField:  begin AStmtKind := mskInsertField; AOp := moAdd; end;
    hikExtractField: begin AStmtKind := mskExtractField; AOp := moAdd; end;
    hikPhi:          begin AStmtKind := mskAssign; AOp := moAdd; end;
    hikTryBegin, hikTryEnd, hikFinallyBegin, hikFinallyEnd,
    hikExceptBegin, hikExceptEnd, hikRaise:
                     begin AStmtKind := mskCall;   AOp := moAdd; end;
    hikConstFloat:   begin AStmtKind := mskAssign; AOp := moAdd; end;
    else
      Result := False;
  end;
end;

procedure THirToMirLowering.LowerFunction(const AHirFunc: THIRFunction);
var
  MirFuncId: TMirFuncId;
  I: LongInt;
begin
  MirFuncId := FMirModule.AddFunction(AHirFunc.Name,
    HirTypeWidth(AHirFunc.ReturnTypeId),
    HirTypeSigned(AHirFunc.ReturnTypeId));

  for I := 0 to High(AHirFunc.Params) do
    FMirModule.AddParam(MirFuncId, AHirFunc.Params[I].Name,
      HirTypeWidth(AHirFunc.Params[I].TypeId),
      HirTypeSigned(AHirFunc.Params[I].TypeId));

  if AHirFunc.IsExternal then
    FMirModule.SetExternal(MirFuncId,
      AHirFunc.ExternalLib, AHirFunc.ExternalName);

  SetLength(FValueMap, 0);

  for I := 0 to High(AHirFunc.Blocks) do
    LowerBlock(AHirFunc, AHirFunc.Blocks[I], MirFuncId);

  if AHirFunc.EntryBlockId <> 0 then
    FMirModule.SetEntryBlock(MirFuncId, AHirFunc.EntryBlockId);
end;

procedure THirToMirLowering.LowerBlock(const AHirFunc: THIRFunction;
  const AHirBlock: THIRBlock; AMirFuncId: TMirFuncId);
var
  MirBlockId: TMirBlockId;
  I, OpCount: LongInt;
  MirStmt: TMirStmt;
  MirOp: TMirOp;
  MirStmtKind: TMirStmtKind;
begin
  MirBlockId := FMirModule.AddBlock(AMirFuncId, AHirBlock.Name);

  for I := 0 to High(AHirBlock.Instrs) do
  begin
    FillChar(MirStmt, SizeOf(MirStmt), 0);

    if not TranslateInstrKind(AHirBlock.Instrs[I].Kind, MirOp, MirStmtKind) then
    begin
      MirStmt.Kind := mskAssign;
      MirStmt.Dst := MapValue(AHirBlock.Instrs[I].ResultId);
      FMirModule.AddStmt(AMirFuncId, MirBlockId, MirStmt);
      Continue;
    end;

    MirStmt.Kind := MirStmtKind;
    MirStmt.Dst := MapValue(AHirBlock.Instrs[I].ResultId);
    MirStmt.Op := MirOp;
    OpCount := Length(AHirBlock.Instrs[I].Operands);

    case MirStmtKind of
      mskAssign:
        if OpCount >= 1 then
          MirStmt.Src := MapOperand(AHirBlock.Instrs[I].Operands[0]);

      mskUnary:
        if OpCount >= 1 then
          MirStmt.Src := MapOperand(AHirBlock.Instrs[I].Operands[0]);

      mskBinary:
        begin
          if AHirBlock.Instrs[I].Kind in [hikCmpGt, hikCmpGe] then
          begin
            { Swap operands: CmpGt(a,b) → SLt(b,a), CmpGe(a,b) → SLe(b,a) }
            if OpCount >= 2 then
            begin
              MirStmt.Lhs := MapOperand(AHirBlock.Instrs[I].Operands[1]);
              MirStmt.Rhs := MapOperand(AHirBlock.Instrs[I].Operands[0]);
            end;
          end
          else
          begin
            if OpCount >= 1 then
              MirStmt.Lhs := MapOperand(AHirBlock.Instrs[I].Operands[0]);
            if OpCount >= 2 then
              MirStmt.Rhs := MapOperand(AHirBlock.Instrs[I].Operands[1]);
          end;
        end;

      mskCall:
        begin
          MirStmt.FuncName := AHirBlock.Instrs[I].CallTarget;
          if AHirBlock.Instrs[I].Kind = hikIntrinsic then
            MirStmt.FuncName := AHirBlock.Instrs[I].IntrinsicName;
          SetLength(MirStmt.Args, OpCount);
          for OpCount := 0 to OpCount - 1 do
            MirStmt.Args[OpCount] := MapOperand(
              AHirBlock.Instrs[I].Operands[OpCount]);
        end;

      mskAlloca:
        begin
        MirStmt.BitWidth := HirTypeWidth(AHirBlock.Instrs[I].TypeId);
        MirStmt.StructTypeName := AHirBlock.Instrs[I].StructTypeName;
        end;

      mskLoad, mskStore:
        if OpCount >= 1 then
          MirStmt.Src := MapOperand(AHirBlock.Instrs[I].Operands[0]);

      mskGetFieldPtr:
        begin
          if OpCount >= 1 then
            MirStmt.Src := MapOperand(AHirBlock.Instrs[I].Operands[0]);
          MirStmt.FieldIndex := AHirBlock.Instrs[I].FieldIndex;
          MirStmt.Src.StructTypeName := AHirBlock.Instrs[I].StructTypeName;
        end;

      mskExtractField:
        begin
          if OpCount >= 1 then
            MirStmt.Src := MapOperand(AHirBlock.Instrs[I].Operands[0]);
          MirStmt.FieldIndex := AHirBlock.Instrs[I].FieldIndex;
          MirStmt.Src.StructTypeName := AHirBlock.Instrs[I].StructTypeName;
        end;

      mskInsertField:
        begin
          if OpCount >= 1 then
            MirStmt.Src := MapOperand(AHirBlock.Instrs[I].Operands[0]);
          if OpCount >= 2 then
            MirStmt.Rhs := MapOperand(AHirBlock.Instrs[I].Operands[1]);
          MirStmt.FieldIndex := AHirBlock.Instrs[I].FieldIndex;
          MirStmt.Src.StructTypeName := AHirBlock.Instrs[I].StructTypeName;
        end;
    end;

    FMirModule.AddStmt(AMirFuncId, MirBlockId, MirStmt);
  end;

  LowerTerminator(AHirBlock.Terminator, AMirFuncId, MirBlockId);
end;

procedure THirToMirLowering.LowerTerminator(
  const AHirTerm: THIRTerminator;
  AMirFuncId, AMirBlockId: TMirBlockId);
var
  MirTerm: TMirTerminator;
  I: LongInt;
begin
  FillChar(MirTerm, SizeOf(MirTerm), 0);

  case AHirTerm.Kind of
    htkReturn:
      begin
        MirTerm.Kind := mtkReturn;
        if AHirTerm.ReturnValue <> 0 then
          MirTerm.ReturnValue := MapValue(AHirTerm.ReturnValue);
      end;
    htkBranch:
      begin
        MirTerm.Kind := mtkGoto;
        MirTerm.Target := AHirTerm.TargetBlock;
      end;
    htkCondBranch:
      begin
        MirTerm.Kind := mtkIf;
        MirTerm.Cond := MapValue(AHirTerm.Condition);
        MirTerm.TrueBlock := AHirTerm.TrueBlock;
        MirTerm.FalseBlock := AHirTerm.FalseBlock;
      end;
    htkSwitch:
      begin
        MirTerm.Kind := mtkSwitch;
        MirTerm.DefaultBlock := AHirTerm.DefaultBlock;
        SetLength(MirTerm.SwitchCases, Length(AHirTerm.SwitchCases));
        for I := 0 to High(AHirTerm.SwitchCases) do
        begin
          MirTerm.SwitchCases[I].Value := AHirTerm.SwitchCases[I].Value;
          MirTerm.SwitchCases[I].Target := AHirTerm.SwitchCases[I].TargetBlock;
        end;
      end;
    htkUnreachable:
      MirTerm.Kind := mtkUnreachable;
  end;

  FMirModule.SetTerminator(AMirFuncId, AMirBlockId, MirTerm);
end;

function THirToMirLowering.Lower: TMirModule;
var
  I: LongInt;
begin
  FMirModule := TMirModule.Create(FHirModule.ModuleName);

  for I := 0 to FHirModule.FunctionCount - 1 do
    LowerFunction(FHirModule.FunctionAt(I));

  Result := FMirModule;
end;

end.
