{**
 * nextpas.compiler.ir.mir.model.pas — Mid-level IR (MIR) data structures
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

unit nextpas.compiler.ir.mir.model;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.core.collections.vec;

type
  {** MIR 值 ID（SSA 虚拟寄存器） }
  TMirValueId = LongInt;
  {** MIR 基本块 ID }
  TMirBlockId = LongInt;
  {** MIR 基本块 ID 动态数组 }
  TMirBlockIdArray = array of TMirBlockId;
  {** MIR 结构体字段 }
  TMirStructField = record
    Name: string;
    BitWidth: LongInt;
    IsSigned: Boolean;
  end;

  TMirStructFieldVec = specialize TVec<TMirStructField>;

  {** MIR 结构体类型 }
  TMirStructType = record
    Name: string;
    { Nested product table owned by module struct-type entry (default heap). }
    Fields: TMirStructFieldVec;
  end;

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
    StructTypeName: string; // 非空时表示该操作数是此 struct 类型
  end;

  {** MIR 语句 }
  TMirStmtKind = (
    mskAssign,     // Dst := Src
    mskCall,       // Dst := Call(Func, Args)
    mskAlloca,     // Dst := alloca(Type)
    mskLoad,       // Dst := *Ptr
    mskStore,      // *Ptr := Src
    mskGetFieldPtr,// Dst := &(Base.FieldIndex)
    mskInsertField, // Dst := insertvalue Base, Value, FieldIndex
    mskExtractField,// Dst := extractvalue Base, FieldIndex
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

  TMirOperandVec = specialize TVec<TMirOperand>;

  {** MIR 语句 }
  TMirStmt = record
    Kind: TMirStmtKind;
    Dst: TMirValueId;        // 目标虚拟寄存器（0 = 无）
    Src: TMirOperand;        // 源操作数
    Lhs: TMirOperand;        // 二元左操作数
    Rhs: TMirOperand;        // 二元右操作数
    Op: TMirOp;              // 一元/二元操作符
    FuncName: string;        // mskCall: 被调用函数名
    { Nested product table owned by block stmt entry (default heap). }
    Args: TMirOperandVec;    // mskCall: 实参列表
    FieldIndex: LongInt;     // mskGetFieldPtr: 字段索引
    BitWidth: LongInt;       // mskAlloca: 分配宽度
    StructTypeName: string;   // 非空时表示 alloca/操作的 struct 类型名
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

  TMirSwitchCaseVec = specialize TVec<TMirSwitchCase>;

  {** MIR 终结符 }
  TMirTerminator = record
    Kind: TMirTermKind;
    ReturnValue: TMirValueId;    // mtkReturn
    Cond: TMirValueId;           // mtkIf
    TrueBlock: TMirBlockId;      // mtkIf
    FalseBlock: TMirBlockId;     // mtkIf
    Target: TMirBlockId;         // mtkGoto
    SwitchValue: TMirValueId;    // mtkSwitch
    { Nested product table owned by block terminator (default heap). }
    SwitchCases: TMirSwitchCaseVec;  // mtkSwitch
    DefaultBlock: TMirBlockId;   // mtkSwitch
  end;

  TMirStmtVec = specialize TVec<TMirStmt>;

  {** MIR 基本块 }
  TMirBlock = record
    Id: TMirBlockId;
    Name: string;
    { Nested product table owned by module block entry (default heap). }
    Stmts: TMirStmtVec;
    Terminator: TMirTerminator;
  end;

  {** MIR 函数参数 }
  TMirParam = record
    Name: string;
    ValueId: TMirValueId;    // 参数对应的虚拟寄存器
    BitWidth: LongInt;
    IsSigned: Boolean;
  end;

  TMirParamVec = specialize TVec<TMirParam>;
  TMirBlockVec = specialize TVec<TMirBlock>;

  {** MIR 函数 }
  TMirFunction = record
    Id: TMirFuncId;
    Name: string;
    ReturnBitWidth: LongInt;     // 0 = void
    ReturnIsSigned: Boolean;
    { Nested product tables owned by module function entry (default heap). }
    Params: TMirParamVec;
    Blocks: TMirBlockVec;
    EntryBlockId: TMirBlockId;
    IsExternal: Boolean;
    ExternalLib: string;
    ExternalName: string;
  end;

  PMirFunction = ^TMirFunction;
  PMirBlock = ^TMirBlock;
  PMirStmt = ^TMirStmt;
  PMirStructType = ^TMirStructType;
  TMirFunctionVec = specialize TVec<TMirFunction>;
  TMirStructTypeVec = specialize TVec<TMirStructType>;

  {** MIR 模块 — 包含所有函数和全局变量 }
  TMirModule = class
  private
    FName: string;
    FFunctions: TMirFunctionVec;
    FNextValueId: TMirValueId;
    FNextBlockId: TMirBlockId;
    FNextFuncId: TMirFuncId;
    FStructTypes: TMirStructTypeVec;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    function ModuleName: string;

    {** 注册结构体类型，返回类型索引 }
    function AddStructType(const AName: string;
      const AFields: array of TMirStructField): LongInt;
    function StructTypeCount: LongInt;
    function StructTypeAt(AIndex: LongInt): TMirStructType;

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
    {** 替换函数参数列表（dead-arg 等优化 pass 写回） }
    procedure SetParams(AFuncId: TMirFuncId; const AParams: array of TMirParam);
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

  {** Deep-clone call Args for stmt copies (inline / hoist). Nil stays nil. }
  function CloneMirOperandVec(const ASrc: TMirOperandVec): TMirOperandVec;
  {** Deep-clone switch cases for terminator copies. Nil stays nil. }
  function CloneMirSwitchCaseVec(
    const ASrc: TMirSwitchCaseVec): TMirSwitchCaseVec;

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

function CloneMirOperandVec(const ASrc: TMirOperandVec): TMirOperandVec;
var
  I: SizeInt;
begin
  if ASrc = nil then
    Exit(nil);
  Result := TMirOperandVec.Create(ASrc.Count);
  for I := 0 to SizeInt(ASrc.Count) - 1 do
    Result.Push(ASrc[SizeUInt(I)]);
end;

function CloneMirSwitchCaseVec(
  const ASrc: TMirSwitchCaseVec): TMirSwitchCaseVec;
var
  I: SizeInt;
begin
  if ASrc = nil then
    Exit(nil);
  Result := TMirSwitchCaseVec.Create(ASrc.Count);
  for I := 0 to SizeInt(ASrc.Count) - 1 do
    Result.Push(ASrc[SizeUInt(I)]);
end;

constructor TMirModule.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FFunctions := TMirFunctionVec.Create;
  FStructTypes := TMirStructTypeVec.Create;
  FNextValueId := 1;
  FNextBlockId := 1;
  FNextFuncId := 1;
end;

destructor TMirModule.Destroy;
var
  I, BI, SI: SizeInt;
  ST: PMirStructType;
  Func: PMirFunction;
  Block: PMirBlock;
  Stmt: PMirStmt;
begin
  if FStructTypes <> nil then
  begin
    for I := 0 to SizeInt(FStructTypes.Count) - 1 do
    begin
      ST := FStructTypes.GetPtr(SizeUInt(I));
      ST^.Fields.Free;
      ST^.Fields := nil;
    end;
  end;
  FStructTypes.Free;
  FStructTypes := nil;
  if FFunctions <> nil then
  begin
    for I := 0 to SizeInt(FFunctions.Count) - 1 do
    begin
      Func := FFunctions.GetPtr(SizeUInt(I));
      Func^.Params.Free;
      Func^.Params := nil;
      if Func^.Blocks <> nil then
      begin
        for BI := 0 to SizeInt(Func^.Blocks.Count) - 1 do
        begin
          Block := Func^.Blocks.GetPtr(SizeUInt(BI));
          if Block^.Stmts <> nil then
          begin
            for SI := 0 to SizeInt(Block^.Stmts.Count) - 1 do
            begin
              Stmt := Block^.Stmts.GetPtr(SizeUInt(SI));
              Stmt^.Args.Free;
              Stmt^.Args := nil;
            end;
          end;
          Block^.Stmts.Free;
          Block^.Stmts := nil;
          Block^.Terminator.SwitchCases.Free;
          Block^.Terminator.SwitchCases := nil;
        end;
      end;
      Func^.Blocks.Free;
      Func^.Blocks := nil;
    end;
  end;
  FFunctions.Free;
  FFunctions := nil;
  inherited Destroy;
end;

function TMirModule.ModuleName: string;
begin
  Result := FName;
end;

function TMirModule.AddStructType(const AName: string;
  const AFields: array of TMirStructField): LongInt;
var
  I: LongInt;
  Entry: TMirStructType;
begin
  Entry := Default(TMirStructType);
  Entry.Name := AName;
  if Length(AFields) > 0 then
    Entry.Fields := TMirStructFieldVec.Create(SizeUInt(Length(AFields)))
  else
    Entry.Fields := TMirStructFieldVec.Create;
  for I := 0 to High(AFields) do
    Entry.Fields.Push(AFields[I]);
  FStructTypes.Push(Entry);
  Result := LongInt(FStructTypes.Count) - 1;
end;

function TMirModule.StructTypeCount: LongInt;
begin
  if FStructTypes = nil then
    Exit(0);
  Result := LongInt(FStructTypes.Count);
end;

function TMirModule.StructTypeAt(AIndex: LongInt): TMirStructType;
begin
  if (FStructTypes <> nil) and (AIndex >= 0) and
    (AIndex < LongInt(FStructTypes.Count)) then
    Result := FStructTypes[SizeUInt(AIndex)]
  else
  begin
    Result.Name := '';
    Result.Fields := nil;
  end;
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
  Func: TMirFunction;
begin
  Func := Default(TMirFunction);
  Func.Id := FNextFuncId;
  Func.Name := AName;
  Func.ReturnBitWidth := AReturnBitWidth;
  Func.ReturnIsSigned := AReturnIsSigned;
  Func.EntryBlockId := 0;
  Func.IsExternal := False;
  FFunctions.Push(Func);
  Result := FNextFuncId;
  Inc(FNextFuncId);
end;

procedure TMirModule.AddParam(AFuncId: TMirFuncId; const AName: string;
  ABitWidth: LongInt; AIsSigned: Boolean);
var
  I: SizeInt;
  Func: PMirFunction;
  Param: TMirParam;
begin
  for I := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(I));
    if Func^.Id = AFuncId then
    begin
      if Func^.Params = nil then
        Func^.Params := TMirParamVec.Create;
      Param.Name := AName;
      Param.ValueId := NewValue;
      Param.BitWidth := ABitWidth;
      Param.IsSigned := AIsSigned;
      Func^.Params.Push(Param);
      Exit;
    end;
  end;
end;

procedure TMirModule.SetParams(AFuncId: TMirFuncId;
  const AParams: array of TMirParam);
var
  I, J: SizeInt;
  Func: PMirFunction;
begin
  for I := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(I));
    if Func^.Id = AFuncId then
    begin
      Func^.Params.Free;
      Func^.Params := nil;
      if Length(AParams) > 0 then
      begin
        Func^.Params := TMirParamVec.Create(SizeUInt(Length(AParams)));
        for J := 0 to High(AParams) do
          Func^.Params.Push(AParams[J]);
      end;
      Exit;
    end;
  end;
end;

procedure TMirModule.SetStmt(AFuncId, ABlockId: TMirBlockId;
  AStmtIndex: LongInt; const AStmt: TMirStmt);
var
  FI, BI: LongInt;
  Func: PMirFunction;
  Block: PMirBlock;
  Old: PMirStmt;
begin
  for FI := 0 to LongInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(FI));
    if Func^.Blocks = nil then
      Continue;
    for BI := 0 to LongInt(Func^.Blocks.Count) - 1 do
    begin
      Block := Func^.Blocks.GetPtr(SizeUInt(BI));
      if Block^.Id = ABlockId then
      begin
        if (Block^.Stmts <> nil) and (AStmtIndex >= 0) and
          (AStmtIndex < LongInt(Block^.Stmts.Count)) then
        begin
          Old := Block^.Stmts.GetPtr(SizeUInt(AStmtIndex));
          { Free previous Args only when ownership actually changes. }
          if Old^.Args <> AStmt.Args then
          begin
            Old^.Args.Free;
            Old^.Args := nil;
          end;
          Old^ := AStmt;
        end;
        Exit;
      end;
    end;
  end;
end;

function TMirModule.GetStmt(AFuncId, ABlockId: TMirBlockId;
  AStmtIndex: LongInt; out AStmt: TMirStmt): Boolean;
var
  FI, BI: LongInt;
  Func: PMirFunction;
  Block: PMirBlock;
begin
  Result := False;
  for FI := 0 to LongInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(FI));
    if Func^.Blocks = nil then
      Continue;
    for BI := 0 to LongInt(Func^.Blocks.Count) - 1 do
    begin
      Block := Func^.Blocks.GetPtr(SizeUInt(BI));
      if Block^.Id = ABlockId then
      begin
        if (Block^.Stmts <> nil) and (AStmtIndex >= 0) and
          (AStmtIndex < LongInt(Block^.Stmts.Count)) then
        begin
          AStmt := Block^.Stmts[SizeUInt(AStmtIndex)];
          Result := True;
        end;
        Exit;
      end;
    end;
  end;
end;

procedure TMirModule.SetExternal(AFuncId: TMirFuncId;
  const ALib, AExternalName: string);
var
  I: SizeInt;
  Func: PMirFunction;
begin
  for I := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(I));
    if Func^.Id = AFuncId then
    begin
      Func^.IsExternal := True;
      Func^.ExternalLib := ALib;
      Func^.ExternalName := AExternalName;
      Exit;
    end;
  end;
end;

function TMirModule.AddBlock(AFuncId: TMirFuncId;
  const AName: string): TMirBlockId;
var
  I: SizeInt;
  Func: PMirFunction;
  Block: TMirBlock;
begin
  Result := NewBlockId;
  for I := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(I));
    if Func^.Id = AFuncId then
    begin
      if Func^.Blocks = nil then
        Func^.Blocks := TMirBlockVec.Create;
      Block := Default(TMirBlock);
      Block.Id := Result;
      Block.Name := AName;
      Block.Terminator.Kind := mtkUnreachable;
      Func^.Blocks.Push(Block);
      Exit;
    end;
  end;
end;

procedure TMirModule.SetEntryBlock(AFuncId: TMirFuncId;
  ABlockId: TMirBlockId);
var
  I: SizeInt;
  Func: PMirFunction;
begin
  for I := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(I));
    if Func^.Id = AFuncId then
    begin
      Func^.EntryBlockId := ABlockId;
      Exit;
    end;
  end;
end;

procedure TMirModule.AddStmt(AFuncId, ABlockId: TMirBlockId;
  const AStmt: TMirStmt);
var
  FI, BI: SizeInt;
  Func: PMirFunction;
  Block: PMirBlock;
begin
  for FI := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(FI));
    if Func^.Id = AFuncId then
    begin
      if Func^.Blocks = nil then
        Exit;
      for BI := 0 to SizeInt(Func^.Blocks.Count) - 1 do
      begin
        Block := Func^.Blocks.GetPtr(SizeUInt(BI));
        if Block^.Id = ABlockId then
        begin
          if Block^.Stmts = nil then
            Block^.Stmts := TMirStmtVec.Create;
          Block^.Stmts.Push(AStmt);
          Exit;
        end;
      end;
      Exit;
    end;
  end;
end;

procedure TMirModule.SetTerminator(AFuncId, ABlockId: TMirBlockId;
  const ATerm: TMirTerminator);
var
  FI, BI: SizeInt;
  Func: PMirFunction;
  Block: PMirBlock;
begin
  for FI := 0 to SizeInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(FI));
    if Func^.Id = AFuncId then
    begin
      if Func^.Blocks = nil then
        Exit;
      for BI := 0 to SizeInt(Func^.Blocks.Count) - 1 do
      begin
        Block := Func^.Blocks.GetPtr(SizeUInt(BI));
        if Block^.Id = ABlockId then
        begin
          if Block^.Terminator.SwitchCases <> ATerm.SwitchCases then
          begin
            Block^.Terminator.SwitchCases.Free;
            Block^.Terminator.SwitchCases := nil;
          end;
          Block^.Terminator := ATerm;
          Exit;
        end;
      end;
      Exit;
    end;
  end;
end;

function TMirModule.FunctionCount: LongInt;
begin
  if FFunctions = nil then
    Exit(0);
  Result := LongInt(FFunctions.Count);
end;

function TMirModule.FunctionAt(AIndex: LongInt): TMirFunction;
begin
  Result := FFunctions[SizeUInt(AIndex)];
end;

function TMirModule.FindFunction(const AName: string): TMirFuncId;
var
  I: LongInt;
begin
  for I := 0 to LongInt(FFunctions.Count) - 1 do
    if FFunctions[SizeUInt(I)].Name = AName then
      Exit(FFunctions[SizeUInt(I)].Id);
  Result := 0;
end;

function TMirModule.Verify(out AMessage: string): Boolean;
var
  FI, BI: LongInt;
  Func: PMirFunction;
begin
  AMessage := '';
  for FI := 0 to LongInt(FFunctions.Count) - 1 do
  begin
    Func := FFunctions.GetPtr(SizeUInt(FI));
    if Func^.EntryBlockId = 0 then
    begin
      AMessage := 'Function "' + Func^.Name + '" has no entry block';
      Exit(False);
    end;
    if (Func^.Blocks = nil) or (Func^.Blocks.Count = 0) then
    begin
      AMessage := 'Function "' + Func^.Name + '" has no blocks';
      Exit(False);
    end;
    for BI := 0 to LongInt(Func^.Blocks.Count) - 1 do
      if Func^.Blocks[SizeUInt(BI)].Terminator.Kind = mtkUnreachable then
      begin
        // warn but don't fail — unreachable is valid for incomplete functions
      end;
  end;
  Result := True;
end;

end.
