{**
 * nextpas.compiler.ir.mir.to_llvm.pas — MIR → LLVM IR translation
 *
 * 将 MIR 模块翻译为 LLVM IR 文本。
 * 对标 rustc_codegen_llvm。
 *
 * 完整实现：MIR 语句 → LLVM IR 指令逐条翻译。
 * 输出缓冲走可选 phase-scratch IAllocator 上的 TVec 行表，
 * 避免二次字符串拼接；调用方传入 PhaseScratch / FScratchAllocator。
 *}

unit nextpas.compiler.ir.mir.to_llvm;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.compiler.ir.mir.model,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

type
  TMirLlvmLineVec = specialize TVec<string>;

  TMirToLlvmTranslator = class
  private
    FModule: TMirModule;
    FAllocator: IAllocator;
    FLines: TMirLlvmLineVec;
    FCurrentLine: string;
    procedure FlushLine;
    procedure Emit(const AText: string);
    procedure EmitLn(const AText: string);
    function BuildOutput: string;
    function LlvmTypeName(ABitWidth: LongInt; AIsSigned: Boolean): string;
    function LlvmTypeForOperand(const AOp: TMirOperand): string;
    function LlvmTypeForStmt(const AStmt: TMirStmt): string;
    function OpStr(const AOp: TMirOperand): string;
    function OpcodeStr(AOp: TMirOp): string;
    procedure TranslateFunction(const AFunc: TMirFunction);
    procedure TranslateBlock(const AFunc: TMirFunction;
      const ABlock: TMirBlock);
    procedure TranslateStmt(const AStmt: TMirStmt);
    procedure TranslateTerminator(const ATerm: TMirTerminator);
    procedure EmitStructTypes;
  public
    constructor Create(const AModule: TMirModule;
      AAllocator: IAllocator = nil);
    destructor Destroy; override;
    function Translate: string;
    procedure SaveToFile(const APath: string);
  end;

implementation

uses
  nextpas.core.text.conv,
  np_llvm_utils;

constructor TMirToLlvmTranslator.Create(const AModule: TMirModule;
  AAllocator: IAllocator);
begin
  inherited Create;
  FModule := AModule;
  FAllocator := AAllocator;
  FCurrentLine := '';
  if FAllocator <> nil then
    FLines := TMirLlvmLineVec.Create(0, FAllocator)
  else
    FLines := TMirLlvmLineVec.Create;
end;

destructor TMirToLlvmTranslator.Destroy;
begin
  FLines.Free;
  inherited Destroy;
end;

procedure TMirToLlvmTranslator.FlushLine;
begin
  FLines.Push(FCurrentLine);
  FCurrentLine := '';
end;

procedure TMirToLlvmTranslator.Emit(const AText: string);
begin
  FCurrentLine := FCurrentLine + AText;
end;

procedure TMirToLlvmTranslator.EmitLn(const AText: string);
begin
  FCurrentLine := FCurrentLine + AText;
  FlushLine;
end;

function TMirToLlvmTranslator.BuildOutput: string;
var
  I: LongInt;
begin
  if FCurrentLine <> '' then
    FlushLine;
  Result := '';
  if FLines.Count > 0 then
    for I := 0 to FLines.Count - 1 do
      Result := Result + FLines[I] + #10;
end;

function TMirToLlvmTranslator.LlvmTypeName(ABitWidth: LongInt;
  AIsSigned: Boolean): string;
begin
  Result := NpBitWidthToLlvmType(ABitWidth, AIsSigned);
end;

function TMirToLlvmTranslator.LlvmTypeForOperand(const AOp: TMirOperand): string;
begin
  if AOp.StructTypeName <> '' then
    Result := '%' + AOp.StructTypeName
  else
    Result := LlvmTypeName(AOp.BitWidth, AOp.IsSigned);
end;

function TMirToLlvmTranslator.LlvmTypeForStmt(const AStmt: TMirStmt): string;
begin
  if AStmt.StructTypeName <> '' then
    Result := '%' + AStmt.StructTypeName
  else
    Result := LlvmTypeName(AStmt.BitWidth, False);
end;

function TMirToLlvmTranslator.OpStr(const AOp: TMirOperand): string;
begin
  case AOp.Kind of
    mokConst:
      Result := LlvmTypeForOperand(AOp) + ' ' +
        IntToStr(AOp.ConstVal.IntVal);
    mokLocal, mokMove:
      Result := LlvmTypeForOperand(AOp) + ' %' +
        IntToStr(AOp.Value);
    else
      Result := 'i32 0';
  end;
end;

function TMirToLlvmTranslator.OpcodeStr(AOp: TMirOp): string;
begin
  case AOp of
    moAdd:  Result := 'add';
    moSub:  Result := 'sub';
    moMul:  Result := 'mul';
    moSDiv: Result := 'sdiv';
    moUDiv: Result := 'udiv';
    moSRem: Result := 'srem';
    moURem: Result := 'urem';
    moNeg:  Result := 'sub';  // neg → sub 0, x
    moNot:  Result := 'xor';  // not → xor x, -1
    moAnd:  Result := 'and';
    moOr:   Result := 'or';
    moXor:  Result := 'xor';
    moShl:  Result := 'shl';
    moLShr: Result := 'lshr';
    moAShr: Result := 'ashr';
    moEq:   Result := 'icmp eq';
    moNe:   Result := 'icmp ne';
    moSLt:  Result := 'icmp slt';
    moULt:  Result := 'icmp ult';
    moSLe:  Result := 'icmp sle';
    moULe:  Result := 'icmp ule';
    moTrunc: Result := 'trunc';
    moZext:  Result := 'zext';
    moSext:  Result := 'sext';
    moBitcast: Result := 'bitcast';
    moSIToFP: Result := 'sitofp';
    moFPToSI: Result := 'fptosi';
    moUIToFP: Result := 'uitofp';
    moFPToUI: Result := 'fptoui';
    else     Result := 'add';
  end;
end;

procedure TMirToLlvmTranslator.EmitStructTypes;
var
  I, J: LongInt;
  ST: TMirStructType;
begin
  for I := 0 to FModule.StructTypeCount - 1 do
  begin
    ST := FModule.StructTypeAt(I);
    Emit('%' + ST.Name + ' = type {');
    if ST.Fields <> nil then
      for J := 0 to LongInt(ST.Fields.Count) - 1 do
      begin
        if J > 0 then Emit(', ');
        Emit(LlvmTypeName(ST.Fields[SizeUInt(J)].BitWidth,
          ST.Fields[SizeUInt(J)].IsSigned));
      end;
    EmitLn('}');
  end;
  if FModule.StructTypeCount > 0 then
    EmitLn('');
end;

procedure TMirToLlvmTranslator.TranslateFunction(const AFunc: TMirFunction);
var
  I: LongInt;
begin
  if AFunc.IsExternal then
  begin
    EmitLn('declare ' + LlvmTypeName(AFunc.ReturnBitWidth,
      AFunc.ReturnIsSigned) + ' @' + AFunc.Name + '(...)');
    Exit;
  end;

  Emit('define ' + LlvmTypeName(AFunc.ReturnBitWidth,
    AFunc.ReturnIsSigned) + ' @' + AFunc.Name + '(');
  if AFunc.Params <> nil then
    for I := 0 to LongInt(AFunc.Params.Count) - 1 do
    begin
      if I > 0 then Emit(', ');
      Emit(LlvmTypeName(AFunc.Params[SizeUInt(I)].BitWidth,
        AFunc.Params[SizeUInt(I)].IsSigned) + ' %' +
        AFunc.Params[SizeUInt(I)].Name);
    end;
  EmitLn(') {');

  if AFunc.Blocks <> nil then
      for I := 0 to LongInt(AFunc.Blocks.Count) - 1 do
    TranslateBlock(AFunc, AFunc.Blocks[SizeUInt(I)]);

  EmitLn('}');
  EmitLn('');
end;

procedure TMirToLlvmTranslator.TranslateBlock(const AFunc: TMirFunction;
  const ABlock: TMirBlock);
var
  I: LongInt;
begin
  EmitLn(ABlock.Name + ':');
  if ABlock.Stmts <> nil then
          for I := 0 to LongInt(ABlock.Stmts.Count) - 1 do
    TranslateStmt(ABlock.Stmts[SizeUInt(I)]);
  TranslateTerminator(ABlock.Terminator);
end;

procedure TMirToLlvmTranslator.TranslateStmt(const AStmt: TMirStmt);
var
  I: LongInt;
  Ty: string;
begin
  case AStmt.Kind of
    mskAssign:
      EmitLn('  %' + IntToStr(AStmt.Dst) + ' = ' + OpStr(AStmt.Src));

    mskAlloca:
      begin
        Ty := LlvmTypeForStmt(AStmt);
        EmitLn('  %' + IntToStr(AStmt.Dst) + ' = alloca ' + Ty);
      end;

    mskLoad:
      begin
        Ty := LlvmTypeForOperand(AStmt.Src);
        EmitLn('  %' + IntToStr(AStmt.Dst) + ' = load ' + Ty +
          ', ' + Ty + '* %' + IntToStr(AStmt.Src.Value));
      end;

    mskStore:
      EmitLn('  store ' + OpStr(AStmt.Src) + ', ' +
        LlvmTypeForOperand(AStmt.Src) +
        '* %' + IntToStr(AStmt.Dst));

    mskGetFieldPtr:
      EmitLn('  %' + IntToStr(AStmt.Dst) + ' = getelementptr ' +
        LlvmTypeForOperand(AStmt.Src) +
        ', ' + LlvmTypeForOperand(AStmt.Src) +
        '* %' + IntToStr(AStmt.Src.Value) +
        ', i32 0, i32 ' + IntToStr(AStmt.FieldIndex));

    mskExtractField:
      EmitLn('  %' + IntToStr(AStmt.Dst) + ' = extractvalue ' +
        LlvmTypeForOperand(AStmt.Src) +
        ' %' + IntToStr(AStmt.Src.Value) +
        ', ' + IntToStr(AStmt.FieldIndex));

    mskInsertField:
      EmitLn('  %' + IntToStr(AStmt.Dst) + ' = insertvalue ' +
        LlvmTypeForOperand(AStmt.Src) +
        ' %' + IntToStr(AStmt.Src.Value) + ', ' +
        OpStr(AStmt.Rhs) +
        ', ' + IntToStr(AStmt.FieldIndex));

    mskUnary:
      begin
        Ty := LlvmTypeForOperand(AStmt.Src);
        case AStmt.Op of
          moNeg:
            EmitLn('  %' + IntToStr(AStmt.Dst) + ' = sub ' + Ty +
              ' 0, %' + IntToStr(AStmt.Src.Value));
          moNot:
            EmitLn('  %' + IntToStr(AStmt.Dst) + ' = xor ' + Ty +
              ' %' + IntToStr(AStmt.Src.Value) + ', -1');
          moTrunc, moZext, moSext, moBitcast, moSIToFP, moFPToSI,
          moUIToFP, moFPToUI:
            EmitLn('  %' + IntToStr(AStmt.Dst) + ' = ' +
              OpcodeStr(AStmt.Op) + ' ' + Ty +
              ' %' + IntToStr(AStmt.Src.Value) + ' to ' +
              LlvmTypeName(AStmt.Dst, False));
          else
            EmitLn('  ; unary op ' + IntToStr(Ord(AStmt.Op)));
        end;
      end;

    mskBinary:
      begin
        Ty := LlvmTypeForOperand(AStmt.Lhs);
        EmitLn('  %' + IntToStr(AStmt.Dst) + ' = ' +
          OpcodeStr(AStmt.Op) + ' ' + Ty + ' ' +
          '%' + IntToStr(AStmt.Lhs.Value) + ', %' +
          IntToStr(AStmt.Rhs.Value));
      end;

    mskCall:
      begin
        Ty := LlvmTypeName(AStmt.Src.BitWidth, AStmt.Src.IsSigned);
        if Ty = 'void' then Ty := 'i32';
        Emit('  %' + IntToStr(AStmt.Dst) + ' = call ' + Ty +
          ' @' + AStmt.FuncName + '(');
        if AStmt.Args <> nil then
          for I := 0 to LongInt(AStmt.Args.Count) - 1 do
          begin
            if I > 0 then Emit(', ');
            Emit(OpStr(AStmt.Args[SizeUInt(I)]));
          end;
        EmitLn(')');
      end;
  end;
end;

procedure TMirToLlvmTranslator.TranslateTerminator(
  const ATerm: TMirTerminator);
var
  I: LongInt;
begin
  case ATerm.Kind of
    mtkReturn:
      if ATerm.ReturnValue = 0 then
        EmitLn('  ret void')
      else
        EmitLn('  ret i32 %' + IntToStr(ATerm.ReturnValue));

    mtkGoto:
      EmitLn('  br label %bb' + IntToStr(ATerm.Target));

    mtkIf:
      EmitLn('  br i1 %' + IntToStr(ATerm.Cond) +
        ', label %bb' + IntToStr(ATerm.TrueBlock) +
        ', label %bb' + IntToStr(ATerm.FalseBlock));

    mtkSwitch:
      begin
        Emit('  switch i32 %' + IntToStr(ATerm.SwitchValue) +
          ', label %bb' + IntToStr(ATerm.DefaultBlock) + ' [');
        if ATerm.SwitchCases <> nil then
          for I := 0 to LongInt(ATerm.SwitchCases.Count) - 1 do
            Emit(' i32 ' + IntToStr(ATerm.SwitchCases[SizeUInt(I)].Value) +
              ', label %bb' + IntToStr(ATerm.SwitchCases[SizeUInt(I)].Target));
        EmitLn(' ]');
      end;

    mtkUnreachable:
      EmitLn('  unreachable');
  end;
end;

function TMirToLlvmTranslator.Translate: string;
var
  I: LongInt;
begin
  FLines.Clear;
  FCurrentLine := '';
  EmitLn('; MIR → LLVM IR');
  EmitLn('; Module: ' + FModule.ModuleName);
  EmitLn('');
  EmitStructTypes;
  for I := 0 to FModule.FunctionCount - 1 do
    TranslateFunction(FModule.FunctionAt(I));
  Result := BuildOutput;
end;

procedure TMirToLlvmTranslator.SaveToFile(const APath: string);
var
  F: TextFile;
  I: LongInt;
begin
  Translate;
  AssignFile(F, APath);
  Rewrite(F);
  if FLines.Count > 0 then
    for I := 0 to FLines.Count - 1 do
      WriteLn(F, FLines[I]);
  CloseFile(F);
end;
end.
