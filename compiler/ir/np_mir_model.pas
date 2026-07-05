{**
 * np_mir_model.pas — Mid-level IR (MIR) data structures
 *
 * 对标 rustc MIR (control-flow graph + SSA basic blocks).
 * MIR 是类型擦除的中间表示，位于 HIR 和 LLVM IR 之间。
 *
 * 设计原则：
 *   - 基本块 + 终结符（CFG）
 *   - SSA 虚拟寄存器（局部变量 → 无限虚拟寄存器）
 *   - 类型擦除（仅保留宽度和符号信息，不保留 Pascal 类型名）
 *   - 所有优化 pass 在此层操作
 *}

unit np_mir_model;

{$mode objfpc}{$H+}

interface

type
  {** MIR 值 ID（SSA 虚拟寄存器） }
  TMirValueId = LongInt;
  {** MIR 基本块 ID }
  TMirBlockId = LongInt;
  {** MIR 函数 ID }
  TMirFuncId = LongInt;

  {** MIR 操作数类型 }
  TMirOperandKind = (
    mokLocal,    // SSA 虚拟寄存器（copy 语义）
    mokMove,     // SSA 虚拟寄存器（move 语义，消费所有权）
    mokConst     // 编译期常量
  );

  {** MIR 常量值 }
  TMirConst = record
    case Kind: Byte of
      0: (IntVal: Int64);
      1: (FloatVal: Double);
      2: (BoolVal: Boolean);
  end;

  {** MIR 操作数 }
  TMirOperand = record
    Kind: TMirOperandKind;
    Value: TMirValueId;    // mokLocal/mokMove: 虚拟寄存器 ID
    ConstVal: TMirConst;   // mokConst: 常量值
    BitWidth: LongInt;     // 类型宽度（位），0 = void
    IsSigned: Boolean;     // 有符号标志
  end;

  {** MIR 语句 }
  TMirStmtKind = (
    mskAssign,     // Dst := Src
    mskCall,       // Dst := Call(Func, Args)
    mskAlloca,     // Dst := alloca(Type)
    mskLoad,       // Dst := *Ptr
    mskStore,      // *Ptr := Src
    mskGetFieldPtr,// Dst := &(Base.FieldIndex)
    mskUnary,      // Dst := Op Src
    mskBinary      // Dst := Lhs Op Rhs
  );

  {** MIR 一元/二元操作符 }
  TMirOp = (
    moAdd, moSub, moMul, moSDiv, moUDiv, moSRem, moURem,
    moNeg, moNot,
    moAnd, moOr, moXor, moShl, moLShr, moAShr,
    moEq, moNe, moSLt, moULt, moSLe, moULe,
    moTrunc, moZext, moSext, moBitcast,
    moSIToFP, moFPToSI, moUIToFP, moFPToUI
  );

  {** MIR 语句 }
  TMirStmt = record
    Kind: TMirStmtKind;
    Dst: TMirValueId;        // 目标虚拟寄存器（0 = 无）
    Src: TMirOperand;        // 源操作数
    Lhs: TMirOperand;        // 二元左操作数
    Rhs: TMirOperand;        // 二元右操作数
    Op: TMirOp;              // 一元/二元操作符
    FuncName: string;        // mskCall: 被调用函数名
    Args: array of TMirOperand;  // mskCall: 实参列表
    FieldIndex: LongInt;     // mskGetFieldPtr: 字段索引
    BitWidth: LongInt;       // mskAlloca: 分配宽度
  end;

  {** MIR 终结符类型 }
  TMirTermKind = (
    mtkReturn,       // return Value
    mtkGoto,         // goto Target
    mtkIf,           // if Cond goto TrueBlock else FalseBlock
    mtkSwitch,       // switch Value { cases } default DefaultBlock
    mtkUnreachable   // unreachable
  );

  {** MIR Switch case }
  TMirSwitchCase = record
    Value: Int64;
    Target: TMirBlockId;
  end;

  {** MIR 终结符 }
  TMirTerminator = record
    Kind: TMirTermKind;
    ReturnValue: TMirValueId;    // mtkReturn
    Cond: TMirValueId;           // mtkIf
    TrueBlock: TMirBlockId;      // mtkIf
    FalseBlock: TMirBlockId;     // mtkIf
    Target: TMirBlockId;         // mtkGoto
    SwitchValue: TMirValueId;    // mtkSwitch
    SwitchCases: array of TMirSwitchCase;  // mtkSwitch
    DefaultBlock: TMirBlockId;   // mtkSwitch
  end;

  {** MIR 基本块 }
  TMirBlock = record
    Id: TMirBlockId;
    Name: string;
    Stmts: array of TMirStmt;
    Terminator: TMirTerminator;
  end;

  {** MIR 函数参数 }
  TMirParam = record
    Name: string;
    ValueId: TMirValueId;    // 参数对应的虚拟寄存器
    BitWidth: LongInt;
    IsSigned: Boolean;
  end;

  {** MIR 函数 }
  TMirFunction = record
    Id: TMirFuncId;
    Name: string;
    ReturnBitWidth: LongInt;     // 0 = void
    ReturnIsSigned: Boolean;
    Params: array of TMirParam;
    Blocks: array of TMirBlock;
    EntryBlockId: TMirBlockId;
    IsExternal: Boolean;
    ExternalLib: string;
    ExternalName: string;
  end;

  {** MIR 模块 — 包含所有函数和全局变量 }
  TMirModule = class
  private
    FName: string;
    FFunctions: array of TMirFunction;
    FNextValueId: TMirValueId;
    FNextBlockId: TMirBlockId;
    FNextFuncId: TMirFuncId;
  public
    constructor Create(const AName: string);
    function ModuleName: string;

    {** 分配新的 SSA 虚拟寄存器 ID }
    function NewValue: TMirValueId;
    {** 分配新的基本块 ID }
    function NewBlockId: TMirBlockId;

    {** 添加函数，返回函数 ID }
    function AddFunction(const AName: string;
      AReturnBitWidth: LongInt; AReturnIsSigned: Boolean): TMirFuncId;
    {** 添加函数参数 }
    procedure AddParam(AFuncId: TMirFuncId; const AName: string;
      ABitWidth: LongInt; AIsSigned: Boolean);
    {** 设置函数为 external }
    procedure SetExternal(AFuncId: TMirFuncId;
      const ALib, AExternalName: string);

    {** 添加基本块，返回块 ID }
    function AddBlock(AFuncId: TMirFuncId;
      const AName: string): TMirBlockId;
    {** 设置入口块 }
    procedure SetEntryBlock(AFuncId: TMirFuncId; ABlockId: TMirBlockId);

    {** 添加语句到基本块 }
    procedure AddStmt(AFuncId, ABlockId: TMirBlockId;
      const AStmt: TMirStmt);
    {** 原地替换指定位置的语句（用于优化 pass） }
    procedure SetStmt(AFuncId, ABlockId: TMirBlockId;
      AStmtIndex: LongInt; const AStmt: TMirStmt);
    {** 获取指定位置的语句 }
    function GetStmt(AFuncId, ABlockId: TMirBlockId;
      AStmtIndex: LongInt; out AStmt: TMirStmt): Boolean;
    {** 设置基本块的终结符 }
    procedure SetTerminator(AFuncId, ABlockId: TMirBlockId;
      const ATerm: TMirTerminator);

    {** 查询函数 }
    function FunctionCount: LongInt;
    function FunctionAt(AIndex: LongInt): TMirFunction;
    function FindFunction(const AName: string): TMirFuncId;

    {** 验证模块完整性（用于单元测试） }
    function Verify(out AMessage: string): Boolean;
  end;

  {** 构造操作数辅助函数 }
  function MirLocal(AValueId: TMirValueId; ABitWidth: LongInt;
    AIsSigned: Boolean): TMirOperand;
  function MirMove(AValueId: TMirValueId; ABitWidth: LongInt;
    AIsSigned: Boolean): TMirOperand;
  function MirIntConst(AValue: Int64; ABitWidth: LongInt): TMirOperand;
  function MirFloatConst(AValue: Double): TMirOperand;
  function MirBoolConst(AValue: Boolean): TMirOperand;

implementation

function MirLocal(AValueId: TMirValueId; ABitWidth: LongInt;
  AIsSigned: Boolean): TMirOperand;
begin
  Result.Kind := mokLocal;
  Result.Value := AValueId;
  Result.BitWidth := ABitWidth;
  Result.IsSigned := AIsSigned;
  Result.ConstVal.IntVal := 0;
end;

function MirMove(AValueId: TMirValueId; ABitWidth: LongInt;
  AIsSigned: Boolean): TMirOperand;
begin
  Result.Kind := mokMove;
  Result.Value := AValueId;
  Result.BitWidth := ABitWidth;
  Result.IsSigned := AIsSigned;
  Result.ConstVal.IntVal := 0;
end;

function MirIntConst(AValue: Int64; ABitWidth: LongInt): TMirOperand;
begin
  Result.Kind := mokConst;
  Result.Value := 0;
  Result.BitWidth := ABitWidth;
  Result.IsSigned := True;
  Result.ConstVal.IntVal := AValue;
end;

function MirFloatConst(AValue: Double): TMirOperand;
begin
  Result.Kind := mokConst;
  Result.Value := 0;
  Result.BitWidth := 64;
  Result.IsSigned := True;
  Result.ConstVal.FloatVal := AValue;
end;

function MirBoolConst(AValue: Boolean): TMirOperand;
begin
  Result.Kind := mokConst;
  Result.Value := 0;
  Result.BitWidth := 1;
  Result.IsSigned := False;
  Result.ConstVal.BoolVal := AValue;
end;

constructor TMirModule.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  SetLength(FFunctions, 0);
  FNextValueId := 1;
  FNextBlockId := 1;
  FNextFuncId := 1;
end;

function TMirModule.ModuleName: string;
begin
  Result := FName;
end;

function TMirModule.NewValue: TMirValueId;
begin
  Result := FNextValueId;
  Inc(FNextValueId);
end;

function TMirModule.NewBlockId: TMirBlockId;
begin
  Result := FNextBlockId;
  Inc(FNextBlockId);
end;

function TMirModule.AddFunction(const AName: string;
  AReturnBitWidth: LongInt; AReturnIsSigned: Boolean): TMirFuncId;
var
  Idx: SizeInt;
begin
  Idx := Length(FFunctions);
  SetLength(FFunctions, Idx + 1);
  FFunctions[Idx].Id := FNextFuncId;
  FFunctions[Idx].Name := AName;
  FFunctions[Idx].ReturnBitWidth := AReturnBitWidth;
  FFunctions[Idx].ReturnIsSigned := AReturnIsSigned;
  FFunctions[Idx].EntryBlockId := 0;
  FFunctions[Idx].IsExternal := False;
  SetLength(FFunctions[Idx].Params, 0);
  SetLength(FFunctions[Idx].Blocks, 0);
  Result := FNextFuncId;
  Inc(FNextFuncId);
end;

procedure TMirModule.AddParam(AFuncId: TMirFuncId; const AName: string;
  ABitWidth: LongInt; AIsSigned: Boolean);
var
  I, Idx: SizeInt;
begin
  for I := 0 to High(FFunctions) do
    if FFunctions[I].Id = AFuncId then
    begin
      Idx := Length(FFunctions[I].Params);
      SetLength(FFunctions[I].Params, Idx + 1);
      FFunctions[I].Params[Idx].Name := AName;
      FFunctions[I].Params[Idx].ValueId := NewValue;
      FFunctions[I].Params[Idx].BitWidth := ABitWidth;
      FFunctions[I].Params[Idx].IsSigned := AIsSigned;
      Exit;
    end;
end;

procedure TMirModule.SetStmt(AFuncId, ABlockId: TMirBlockId;
  AStmtIndex: LongInt; const AStmt: TMirStmt);
var
  FI, BI: LongInt;
begin
  for FI := 0 to High(FFunctions) do
    for BI := 0 to High(FFunctions[FI].Blocks) do
      if FFunctions[FI].Blocks[BI].Id = ABlockId then
      begin
        if (AStmtIndex >= 0) and (AStmtIndex < Length(FFunctions[FI].Blocks[BI].Stmts)) then
          FFunctions[FI].Blocks[BI].Stmts[AStmtIndex] := AStmt;
        Exit;
      end;
end;

function TMirModule.GetStmt(AFuncId, ABlockId: TMirBlockId;
  AStmtIndex: LongInt; out AStmt: TMirStmt): Boolean;
var
  FI, BI: LongInt;
begin
  Result := False;
  for FI := 0 to High(FFunctions) do
    for BI := 0 to High(FFunctions[FI].Blocks) do
      if FFunctions[FI].Blocks[BI].Id = ABlockId then
      begin
        if (AStmtIndex >= 0) and (AStmtIndex < Length(FFunctions[FI].Blocks[BI].Stmts)) then
        begin
          AStmt := FFunctions[FI].Blocks[BI].Stmts[AStmtIndex];
          Result := True;
        end;
        Exit;
      end;
end;

procedure TMirModule.SetExternal(AFuncId: TMirFuncId;
  const ALib, AExternalName: string);
var
  I: SizeInt;
begin
  for I := 0 to High(FFunctions) do
    if FFunctions[I].Id = AFuncId then
    begin
      FFunctions[I].IsExternal := True;
      FFunctions[I].ExternalLib := ALib;
      FFunctions[I].ExternalName := AExternalName;
      Exit;
    end;
end;

function TMirModule.AddBlock(AFuncId: TMirFuncId;
  const AName: string): TMirBlockId;
var
  I, Idx: SizeInt;
begin
  Result := NewBlockId;
  for I := 0 to High(FFunctions) do
    if FFunctions[I].Id = AFuncId then
    begin
      Idx := Length(FFunctions[I].Blocks);
      SetLength(FFunctions[I].Blocks, Idx + 1);
      FFunctions[I].Blocks[Idx].Id := Result;
      FFunctions[I].Blocks[Idx].Name := AName;
      SetLength(FFunctions[I].Blocks[Idx].Stmts, 0);
      FFunctions[I].Blocks[Idx].Terminator.Kind := mtkUnreachable;
      Exit;
    end;
end;

procedure TMirModule.SetEntryBlock(AFuncId: TMirFuncId;
  ABlockId: TMirBlockId);
var
  I: SizeInt;
begin
  for I := 0 to High(FFunctions) do
    if FFunctions[I].Id = AFuncId then
    begin
      FFunctions[I].EntryBlockId := ABlockId;
      Exit;
    end;
end;

procedure TMirModule.AddStmt(AFuncId, ABlockId: TMirBlockId;
  const AStmt: TMirStmt);
var
  FI, BI, Idx: SizeInt;
begin
  for FI := 0 to High(FFunctions) do
    if FFunctions[FI].Id = AFuncId then
    begin
      for BI := 0 to High(FFunctions[FI].Blocks) do
        if FFunctions[FI].Blocks[BI].Id = ABlockId then
        begin
          Idx := Length(FFunctions[FI].Blocks[BI].Stmts);
          SetLength(FFunctions[FI].Blocks[BI].Stmts, Idx + 1);
          FFunctions[FI].Blocks[BI].Stmts[Idx] := AStmt;
          Exit;
        end;
      Exit;
    end;
end;

procedure TMirModule.SetTerminator(AFuncId, ABlockId: TMirBlockId;
  const ATerm: TMirTerminator);
var
  FI, BI: SizeInt;
begin
  for FI := 0 to High(FFunctions) do
    if FFunctions[FI].Id = AFuncId then
    begin
      for BI := 0 to High(FFunctions[FI].Blocks) do
        if FFunctions[FI].Blocks[BI].Id = ABlockId then
        begin
          FFunctions[FI].Blocks[BI].Terminator := ATerm;
          Exit;
        end;
      Exit;
    end;
end;

function TMirModule.FunctionCount: LongInt;
begin
  Result := Length(FFunctions);
end;

function TMirModule.FunctionAt(AIndex: LongInt): TMirFunction;
begin
  Result := FFunctions[AIndex];
end;

function TMirModule.FindFunction(const AName: string): TMirFuncId;
var
  I: LongInt;
begin
  for I := 0 to High(FFunctions) do
    if FFunctions[I].Name = AName then
      Exit(FFunctions[I].Id);
  Result := 0;
end;

function TMirModule.Verify(out AMessage: string): Boolean;
var
  FI, BI: LongInt;
begin
  AMessage := '';
  for FI := 0 to High(FFunctions) do
  begin
    if FFunctions[FI].EntryBlockId = 0 then
    begin
      AMessage := 'Function "' + FFunctions[FI].Name + '" has no entry block';
      Exit(False);
    end;
    if Length(FFunctions[FI].Blocks) = 0 then
    begin
      AMessage := 'Function "' + FFunctions[FI].Name + '" has no blocks';
      Exit(False);
    end;
    for BI := 0 to High(FFunctions[FI].Blocks) do
      if FFunctions[FI].Blocks[BI].Terminator.Kind = mtkUnreachable then
      begin
        // warn but don't fail — unreachable is valid for incomplete functions
      end;
  end;
  Result := True;
end;

end.
