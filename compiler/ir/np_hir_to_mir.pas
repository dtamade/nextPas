{**
 * np_hir_to_mir.pas — HIR → MIR lowering pass
 *
 * 将 HIR（高层类型化 AST）降级为 MIR（中层级控制流图）。
 * 这是 MIR 管线的入口点。
 *
 * 对标 rustc_mir_build::build。
 *
 * 当前状态：框架就绪，实际降级逻辑在阶段 1.3b 完整实现。
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
   *}
  THirToMirLowering = class
  private
    FHirModule: THIRModule;
    FMirModule: TMirModule;
    function HirTypeWidth(ATypeId: THIRTypeId): LongInt;
    function HirTypeSigned(ATypeId: THIRTypeId): Boolean;
    procedure LowerFunction(const AHirFunc: THIRFunction);
    procedure LowerBlock(const AHirFunc: THIRFunction;
      const AHirBlock: THIRBlock; AMirFuncId: TMirFuncId);
  public
    constructor Create(const AHirModule: THIRModule);
    destructor Destroy; override;

    {** 执行降级，返回 MIR 模块 }
    function Lower: TMirModule;
  end;

implementation

constructor THirToMirLowering.Create(const AHirModule: THIRModule);
begin
  inherited Create;
  FHirModule := AHirModule;
  FMirModule := nil;
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

procedure THirToMirLowering.LowerFunction(const AHirFunc: THIRFunction);
var
  MirFuncId: TMirFuncId;
  I: LongInt;
begin
  MirFuncId := FMirModule.AddFunction(AHirFunc.Name,
    HirTypeWidth(AHirFunc.ReturnTypeId),
    HirTypeSigned(AHirFunc.ReturnTypeId));

  // Lower parameters
  for I := 0 to High(AHirFunc.Params) do
    FMirModule.AddParam(MirFuncId, AHirFunc.Params[I].Name,
      HirTypeWidth(AHirFunc.Params[I].TypeId),
      HirTypeSigned(AHirFunc.Params[I].TypeId));

  if AHirFunc.IsExternal then
    FMirModule.SetExternal(MirFuncId,
      AHirFunc.ExternalLib, AHirFunc.ExternalName);

  // Lower blocks
  for I := 0 to High(AHirFunc.Blocks) do
    LowerBlock(AHirFunc, AHirFunc.Blocks[I], MirFuncId);

  if AHirFunc.EntryBlockId <> 0 then
    FMirModule.SetEntryBlock(MirFuncId, AHirFunc.EntryBlockId);
end;

procedure THirToMirLowering.LowerBlock(const AHirFunc: THIRFunction;
  const AHirBlock: THIRBlock; AMirFuncId: TMirFuncId);
var
  MirBlockId: TMirBlockId;
  I: LongInt;
  MirStmt: TMirStmt;
  MirTerm: TMirTerminator;
begin
  MirBlockId := FMirModule.AddBlock(AMirFuncId, AHirBlock.Name);

  // Lower instructions (simplified — full lowering in 1.3b)
  for I := 0 to High(AHirBlock.Instrs) do
  begin
    FillChar(MirStmt, SizeOf(MirStmt), 0);
    MirStmt.Kind := mskAssign;
    MirStmt.Dst := AHirBlock.Instrs[I].ResultId;
    FMirModule.AddStmt(AMirFuncId, MirBlockId, MirStmt);
  end;

  // Lower terminator
  FillChar(MirTerm, SizeOf(MirTerm), 0);
  case AHirBlock.Terminator.Kind of
    htkReturn:
      begin
        MirTerm.Kind := mtkReturn;
        MirTerm.ReturnValue := AHirBlock.Terminator.ReturnValue;
      end;
    htkBranch:
      begin
        MirTerm.Kind := mtkGoto;
        MirTerm.Target := AHirBlock.Terminator.TargetBlock;
      end;
    htkCondBranch:
      begin
        MirTerm.Kind := mtkIf;
        MirTerm.Cond := AHirBlock.Terminator.Condition;
        MirTerm.TrueBlock := AHirBlock.Terminator.TrueBlock;
        MirTerm.FalseBlock := AHirBlock.Terminator.FalseBlock;
      end;
    htkSwitch:
      begin
        MirTerm.Kind := mtkSwitch;
        MirTerm.SwitchValue := 0; // TODO: map from HIR
        MirTerm.DefaultBlock := AHirBlock.Terminator.DefaultBlock;
      end;
    htkUnreachable:
      MirTerm.Kind := mtkUnreachable;
  end;
  FMirModule.SetTerminator(AMirFuncId, MirBlockId, MirTerm);
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
