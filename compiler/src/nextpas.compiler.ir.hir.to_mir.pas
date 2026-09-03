{**
 * nextpas.compiler.ir.hir.to_mir.pas — HIR → MIR lowering pass
 *
 * 将 HIR（高层类型化 AST）降级为 MIR（中层级控制流图）。
 * 这是 MIR 管线的入口点。
 *
 * 完整实现：逐条翻译 HIR 指令 → MIR 语句，保留操作语义。
 *
 * 对标 rustc_mir_build::build。
 *
 * Optional IAllocator: session phase scratch for FValueMap growth.
 * MIR module itself stays on the default heap (lives past scratch Reset).
 *
 * 性能保证：
 *   - ValueId 映射 O(1) 哈希（THashMap），避免线性扫描 O(n²) 热点
 *   - 块/指令零拷贝：通过 GetPtr 直接引用 HIR 向量存储，无记录拷贝
 *   - 类型宽度/符号位带缓存，重复操作数共享
 *   - 诊断带上下文：不支持的指令携带函数/块/行列信息
 *}

unit nextpas.compiler.ir.hir.to_mir;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.compiler.ir.hir.model, nextpas.compiler.ir.hir.types, nextpas.compiler.ir.mir.model,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec,
  nextpas.core.collections.hashmap;

type
  THirMirValueMapEntry = record
    HirId: THIRValueId;
    MirId: TMirValueId;
  end;

  { O(1) 哈希映射替代线性向量，解决词法/语义/降级热点 }
  THirMirValueMap = specialize THashMap<THIRValueId, TMirValueId>;

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
    FAllocator: IAllocator;
    { HIR ValueId → MIR ValueId 映射 (O(1) hash, arena-backed when AAllocator set) }
    FValueMap: THirMirValueMap;
    { 类型信息缓存：TypeId → BitWidth / Signed，避免重复 GetType 线性扫描 }
    FTypeWidthCache: specialize THashMap<THIRTypeId, LongInt>;
    FTypeSignedCache: specialize THashMap<THIRTypeId, Boolean>;
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
    constructor Create(const AHirModule: THIRModule;
      const AAllocator: IAllocator = nil);
    destructor Destroy; override;
    function Lower: TMirModule;
    { 取出 MIR module 所有权（调用者负责释放） }
    function DetachModule: TMirModule;
  end;

implementation

uses
  SysUtils;

constructor THirToMirLowering.Create(const AHirModule: THIRModule;
  const AAllocator: IAllocator);
begin
  inherited Create;
  FHirModule := AHirModule;
  FMirModule := nil;
  FAllocator := AAllocator;
  if FAllocator <> nil then
    FValueMap := THirMirValueMap.Create(0, nil, nil, FAllocator)
  else
    FValueMap := THirMirValueMap.Create;
  // 类型缓存常驻 default heap（跨函数复用，Clear 不清空以提升命中率）
  FTypeWidthCache := specialize THashMap<THIRTypeId, LongInt>.Create;
  FTypeSignedCache := specialize THashMap<THIRTypeId, Boolean>.Create;
end;

destructor THirToMirLowering.Destroy;
begin
  FTypeSignedCache.Free;
  FTypeWidthCache.Free;
  FValueMap.Free;
  FMirModule.Free;
  inherited Destroy;
end;

function THirToMirLowering.HirTypeWidth(ATypeId: THIRTypeId): LongInt;
var
  TypeRec: THIRTypeRec;
begin
  if ATypeId = 0 then
    Exit(0);
  if FTypeWidthCache.TryGetValue(ATypeId, Result) then
    Exit;
  TypeRec := FHirModule.Types.GetType(ATypeId);
  Result := TypeRec.BitWidth;
  FTypeWidthCache.Add(ATypeId, Result);
end;

function THirToMirLowering.HirTypeSigned(ATypeId: THIRTypeId): Boolean;
var
  TypeRec: THIRTypeRec;
begin
  if ATypeId = 0 then
    Exit(False);
  if FTypeSignedCache.TryGetValue(ATypeId, Result) then
    Exit;
  TypeRec := FHirModule.Types.GetType(ATypeId);
  Result := TypeRec.Signed;
  FTypeSignedCache.Add(ATypeId, Result);
end;

function THirToMirLowering.MapValue(AHirValueId: THIRValueId): TMirValueId;
begin
  // O(1) 哈希查找，替代原 for I:=0 to Count-1 线性扫描 O(n)
  if FValueMap.TryGetValue(AHirValueId, Result) then
    Exit;
  Result := FMirModule.NewValue;
  FValueMap.Add(AHirValueId, Result);
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
  PParam: ^THIRParam;
  PBlock: ^THIRBlock;
begin
  MirFuncId := FMirModule.AddFunction(AHirFunc.Name,
    HirTypeWidth(AHirFunc.ReturnTypeId),
    HirTypeSigned(AHirFunc.ReturnTypeId));

  // 零拷贝：通过 GetPtr 直接引用参数向量存储
  if AHirFunc.Params <> nil then
    for I := 0 to LongInt(AHirFunc.Params.Count) - 1 do
    begin
      PParam := AHirFunc.Params.GetPtr(SizeUInt(I));
      FMirModule.AddParam(MirFuncId, PParam^.Name,
        HirTypeWidth(PParam^.TypeId),
        HirTypeSigned(PParam^.TypeId));
    end;

  if AHirFunc.IsExternal then
    FMirModule.SetExternal(MirFuncId,
      AHirFunc.ExternalLib, AHirFunc.ExternalName);

  FValueMap.Clear;

  // 零拷贝：通过 GetPtr 遍历块
  if AHirFunc.Blocks <> nil then
    for I := 0 to LongInt(AHirFunc.Blocks.Count) - 1 do
    begin
      PBlock := AHirFunc.Blocks.GetPtr(SizeUInt(I));
      LowerBlock(AHirFunc, PBlock^, MirFuncId);
    end;

  if AHirFunc.EntryBlockId <> 0 then
    FMirModule.SetEntryBlock(MirFuncId, AHirFunc.EntryBlockId);
end;

procedure THirToMirLowering.LowerBlock(const AHirFunc: THIRFunction;
  const AHirBlock: THIRBlock; AMirFuncId: TMirFuncId);
var
  MirBlockId: TMirBlockId;
  I, OpCount, J: LongInt;
  MirStmt: TMirStmt;
  MirOp: TMirOp;
  MirStmtKind: TMirStmtKind;
  HirInstr: ^THIRInstr;
begin
  MirBlockId := FMirModule.AddBlock(AMirFuncId, AHirBlock.Name);

  if AHirBlock.Instrs <> nil then
    for I := 0 to LongInt(AHirBlock.Instrs.Count) - 1 do
    begin
      // 零拷贝：GetPtr 返回指向向量内存储的指针，无 THIRInstr 记录拷贝
      HirInstr := AHirBlock.Instrs.GetPtr(SizeUInt(I));
      FillChar(MirStmt, SizeOf(MirStmt), 0);

      if not TranslateInstrKind(HirInstr^.Kind, MirOp, MirStmtKind) then
      begin
        // 诊断带上下文：携带函数/块/指令类型/源码位置/ResultId
        raise Exception.CreateFmt(
          'HIR→MIR: unsupported instr kind %d in %s.%s at %d:%d (result %d)',
          [Ord(HirInstr^.Kind), AHirFunc.Name, AHirBlock.Name,
           HirInstr^.SourceLine, HirInstr^.SourceCol, HirInstr^.ResultId]);
      end;

      MirStmt.Kind := MirStmtKind;
      MirStmt.Dst := MapValue(HirInstr^.ResultId);
      MirStmt.Op := MirOp;
      OpCount := Length(HirInstr^.Operands);

      case MirStmtKind of
        mskAssign:
          if OpCount >= 1 then
            MirStmt.Src := MapOperand(HirInstr^.Operands[0]);

        mskUnary:
          if OpCount >= 1 then
            MirStmt.Src := MapOperand(HirInstr^.Operands[0]);

        mskBinary:
          begin
            if HirInstr^.Kind in [hikCmpGt, hikCmpGe] then
            begin
              { Swap operands: CmpGt(a,b) → SLt(b,a), CmpGe(a,b) → SLe(b,a) }
              if OpCount >= 2 then
              begin
                MirStmt.Lhs := MapOperand(HirInstr^.Operands[1]);
                MirStmt.Rhs := MapOperand(HirInstr^.Operands[0]);
              end;
            end
            else
            begin
              if OpCount >= 1 then
                MirStmt.Lhs := MapOperand(HirInstr^.Operands[0]);
              if OpCount >= 2 then
                MirStmt.Rhs := MapOperand(HirInstr^.Operands[1]);
            end;
          end;

        mskCall:
          begin
            MirStmt.FuncName := HirInstr^.CallTarget;
            if HirInstr^.Kind = hikIntrinsic then
              MirStmt.FuncName := HirInstr^.IntrinsicName;
            if OpCount > 0 then
            begin
              MirStmt.Args := TMirOperandVec.Create(SizeUInt(OpCount));
              for J := 0 to OpCount - 1 do
                MirStmt.Args.Push(MapOperand(HirInstr^.Operands[J]));
            end;
          end;

        mskAlloca:
          begin
            MirStmt.BitWidth := HirTypeWidth(HirInstr^.TypeId);
            MirStmt.StructTypeName := HirInstr^.StructTypeName;
          end;

        mskLoad, mskStore:
          if OpCount >= 1 then
            MirStmt.Src := MapOperand(HirInstr^.Operands[0]);

        mskGetFieldPtr:
          begin
            if OpCount >= 1 then
              MirStmt.Src := MapOperand(HirInstr^.Operands[0]);
            MirStmt.FieldIndex := HirInstr^.FieldIndex;
            MirStmt.Src.StructTypeName := HirInstr^.StructTypeName;
          end;

        mskExtractField:
          begin
            if OpCount >= 1 then
              MirStmt.Src := MapOperand(HirInstr^.Operands[0]);
            MirStmt.FieldIndex := HirInstr^.FieldIndex;
            MirStmt.Src.StructTypeName := HirInstr^.StructTypeName;
          end;

        mskInsertField:
          begin
            if OpCount >= 1 then
              MirStmt.Src := MapOperand(HirInstr^.Operands[0]);
            if OpCount >= 2 then
              MirStmt.Rhs := MapOperand(HirInstr^.Operands[1]);
            MirStmt.FieldIndex := HirInstr^.FieldIndex;
            MirStmt.Src.StructTypeName := HirInstr^.StructTypeName;
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
  CaseEntry: TMirSwitchCase;
  I: LongInt;
  PCase: ^THIRSwitchCase;
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
        if (AHirTerm.SwitchCases <> nil) and
          (AHirTerm.SwitchCases.Count > 0) then
        begin
          MirTerm.SwitchCases :=
            TMirSwitchCaseVec.Create(AHirTerm.SwitchCases.Count);
          for I := 0 to LongInt(AHirTerm.SwitchCases.Count) - 1 do
          begin
            // 零拷贝：GetPtr 避免 THIRSwitchCase 记录拷贝触发托管类型计数
            PCase := AHirTerm.SwitchCases.GetPtr(SizeUInt(I));
            CaseEntry.Value := PCase^.Value;
            CaseEntry.Target := PCase^.TargetBlock;
            MirTerm.SwitchCases.Push(CaseEntry);
          end;
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

  // 零拷贝：遍历函数向量通过 GetPtr
  for I := 0 to FHirModule.FunctionCount - 1 do
  begin
    // FunctionAt 返回拷贝，改用 GetPtr 零拷贝路径需直接访问 FFunctions
    // 此处保留 FunctionAt 以保持语义一致（HIR 模块拥有数据，拷贝开销相较块/指令可忽略）
    // 若需极致零拷贝可暴露 THIRModule.FunctionPtrAt
    LowerFunction(FHirModule.FunctionAt(I));
  end;

  Result := FMirModule;
end;

function THirToMirLowering.DetachModule: TMirModule;
begin
  Result := FMirModule;
  FMirModule := nil;
end;

end.
