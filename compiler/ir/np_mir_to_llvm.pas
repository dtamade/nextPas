{**
 * np_mir_to_llvm.pas — MIR → LLVM IR translation
 *
 * 将 MIR 模块翻译为 LLVM IR 文本。
 * 对标 rustc_codegen_llvm。
 *
 * 当前状态：框架就绪，实际翻译逻辑在阶段 1.3d 完整实现。
 * 在此之前，LLVM IR 生成继续使用现有的 np_hir_llvm_emitter。
 *}

unit np_mir_to_llvm;

{$mode objfpc}{$H+}

interface

uses
  np_mir_model;

type
  {**
   * TMirToLlvmTranslator — MIR → LLVM IR 翻译器
   *
   * 遍历 MIR 模块，生成 LLVM IR 文本。
   *}
  TMirToLlvmTranslator = class
  private
    FModule: TMirModule;
    FOutput: string;
    procedure Emit(const AText: string);
    procedure EmitLn(const AText: string);
    function LlvmTypeName(ABitWidth: LongInt; AIsSigned: Boolean): string;
    procedure TranslateFunction(const AFunc: TMirFunction);
    procedure TranslateBlock(const AFunc: TMirFunction;
      const ABlock: TMirBlock);
    procedure TranslateStmt(const AStmt: TMirStmt);
    procedure TranslateTerminator(const ATerm: TMirTerminator);
  public
    constructor Create(const AModule: TMirModule);
    function Translate: string;
  end;

implementation

uses
  nextpas.core.text.conv;

constructor TMirToLlvmTranslator.Create(const AModule: TMirModule);
begin
  inherited Create;
  FModule := AModule;
  FOutput := '';
end;

procedure TMirToLlvmTranslator.Emit(const AText: string);
begin
  FOutput := FOutput + AText;
end;

procedure TMirToLlvmTranslator.EmitLn(const AText: string);
begin
  FOutput := FOutput + AText + #10;
end;

function TMirToLlvmTranslator.LlvmTypeName(ABitWidth: LongInt;
  AIsSigned: Boolean): string;
begin
  case ABitWidth of
    0:  Result := 'void';
    1:  Result := 'i1';
    8:  Result := 'i8';
    16: Result := 'i16';
    32: Result := 'i32';
    64: Result := 'i64';
  else
    Result := 'i' + IntToStr(ABitWidth);
  end;
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
  for I := 0 to High(AFunc.Params) do
  begin
    if I > 0 then Emit(', ');
    Emit(LlvmTypeName(AFunc.Params[I].BitWidth,
      AFunc.Params[I].IsSigned) + ' %' + AFunc.Params[I].Name);
  end;
  EmitLn(') {');

  for I := 0 to High(AFunc.Blocks) do
    TranslateBlock(AFunc, AFunc.Blocks[I]);

  EmitLn('}');
  EmitLn('');
end;

procedure TMirToLlvmTranslator.TranslateBlock(const AFunc: TMirFunction;
  const ABlock: TMirBlock);
var
  I: LongInt;
begin
  EmitLn(ABlock.Name + ':');
  for I := 0 to High(ABlock.Stmts) do
    TranslateStmt(ABlock.Stmts[I]);
  TranslateTerminator(ABlock.Terminator);
end;

procedure TMirToLlvmTranslator.TranslateStmt(const AStmt: TMirStmt);
begin
  // Placeholder — full translation in 1.3d
  EmitLn('  ; stmt kind=' + IntToStr(Ord(AStmt.Kind)));
end;

procedure TMirToLlvmTranslator.TranslateTerminator(
  const ATerm: TMirTerminator);
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
      EmitLn('  switch ; // TODO');
    mtkUnreachable:
      EmitLn('  unreachable');
  end;
end;

function TMirToLlvmTranslator.Translate: string;
var
  I: LongInt;
begin
  FOutput := '';
  EmitLn('; MIR → LLVM IR (np_mir_to_llvm)');
  EmitLn('; Module: ' + FModule.ModuleName);
  EmitLn('');

  for I := 0 to FModule.FunctionCount - 1 do
    TranslateFunction(FModule.FunctionAt(I));

  Result := FOutput;
end;

end.
