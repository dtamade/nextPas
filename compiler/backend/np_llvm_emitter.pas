unit np_llvm_emitter;

{$mode objfpc}{$H+}
{$UNITPATH ../ir}
{$UNITPATH ../targets}

interface

uses
  SysUtils, np_mir_model, np_target_facts;

type
  TLLvmStringArray = array of string;

  TLlvmEmitter = class
  private
    FMirModel: TMirModel;
    FTargetFacts: TTargetFactsView;
    function ResolveExitCode: LongInt;
    function CollectWriteLines: TLLvmStringArray;
    function EscapeLLVMString(const AValue: string): string;
    procedure EmitTargetHeader(var AIrFile: Text);
    procedure EmitGlobalConstStrings(
      var AIrFile: Text;
      const AWriteLines: TLLvmStringArray
    );
    procedure EmitLegacyMain(var AIrFile: Text);
    procedure EmitRuntimeMain(var AIrFile: Text);
  public
    constructor Create(
      const AMirModel: TMirModel;
      const ATargetFacts: TTargetFactsView
    );
    function EmitToFile(const APath: string): Boolean;
  end;

implementation

const
  LegacyExitAsmFmt =
    '  call void asm sideeffect "movq $$60, %%rax; syscall", "{rdi},~{rax},~{rcx},~{r11}"(i64 %d)';
  LegacyWriteAsmFmt =
    '  call void asm sideeffect "movq $$1, %%rax; syscall", "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr @.str.%d, i64 %d)';

constructor TLlvmEmitter.Create(
  const AMirModel: TMirModel;
  const ATargetFacts: TTargetFactsView
);
begin
  inherited Create;
  FMirModel := AMirModel;
  FTargetFacts := ATargetFacts;
end;

function TLlvmEmitter.ResolveExitCode: LongInt;
var
  Index: LongInt;
  Op: TMirOperation;
  Parsed: LongInt;
  ParseCode: Word;
begin
  Result := 0;
  if FMirModel = nil then
    Exit;
  for Index := 0 to FMirModel.OperationCount - 1 do
  begin
    Op := FMirModel.OperationAt(Index);
    if Op.Kind <> 'halt' then
      Continue;
    if Trim(Op.Operand) = '' then
      Exit(0);
    Val(Op.Operand, Parsed, ParseCode);
    if ParseCode = 0 then
      Exit(Parsed);
    Exit(0);
  end;
end;

function TLlvmEmitter.CollectWriteLines: TLLvmStringArray;
var
  Index: LongInt;
  Op: TMirOperation;
begin
  Result := nil;
  if FMirModel = nil then
    Exit;
  for Index := 0 to FMirModel.OperationCount - 1 do
  begin
    Op := FMirModel.OperationAt(Index);
    if Op.Kind = 'write-line' then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Op.Operand;
    end;
  end;
end;

function TLlvmEmitter.EscapeLLVMString(const AValue: string): string;
var
  Index: SizeInt;
begin
  Result := '';
  for Index := 1 to Length(AValue) do
  begin
    case AValue[Index] of
      '\': Result := Result + '\\';
      '"': Result := Result + '\"';
      #10: Result := Result + '\0A';
      #13: Result := Result + '\0D';
      #9: Result := Result + '\09';
      #0: Result := Result + '\00';
    else
      if Ord(AValue[Index]) < 32 then
        Result := Result + '\0' + LowerCase(IntToHex(Ord(AValue[Index]), 1))
      else
        Result := Result + AValue[Index];
    end;
  end;
end;

procedure TLlvmEmitter.EmitTargetHeader(var AIrFile: Text);
begin
  if FTargetFacts.LlvmTriple <> '' then
    WriteLn(AIrFile, 'target triple = "', FTargetFacts.LlvmTriple, '"');
  if FTargetFacts.LlvmDataLayout <> '' then
    WriteLn(AIrFile, 'target datalayout = "', FTargetFacts.LlvmDataLayout, '"');
  WriteLn(AIrFile);
end;

procedure TLlvmEmitter.EmitGlobalConstStrings(
  var AIrFile: Text;
  const AWriteLines: TLLvmStringArray
);
var
  Index: LongInt;
  StrLen: LongInt;
begin
  for Index := 0 to High(AWriteLines) do
  begin
    StrLen := Length(AWriteLines[Index]);
    WriteLn(AIrFile, '@.str.', Index, ' = private constant [',
      StrLen + 1, ' x i8] c"', EscapeLLVMString(AWriteLines[Index]),
      '\00"');
  end;
end;

procedure TLlvmEmitter.EmitLegacyMain(var AIrFile: Text);
var
  ExitCode: LongInt;
  WriteLines: TLLvmStringArray;
  Index: LongInt;
  StrLen: LongInt;
begin
  ExitCode := ResolveExitCode;
  WriteLines := CollectWriteLines;

  EmitTargetHeader(AIrFile);
  EmitGlobalConstStrings(AIrFile, WriteLines);

  WriteLn(AIrFile);
  WriteLn(AIrFile, 'define void @_start() noreturn {');
  WriteLn(AIrFile, 'entry:');

  for Index := 0 to High(WriteLines) do
  begin
    StrLen := Length(WriteLines[Index]);
    WriteLn(AIrFile,
      '  call void asm sideeffect "movq $$1, %rax; syscall", "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr @.str.',
      Index, ', i64 ', StrLen, ')');
  end;

  WriteLn(AIrFile,
    '  call void asm sideeffect "movq $$60, %rax; syscall", "{rdi},~{rax},~{rcx},~{r11}"(i64 ',
    ExitCode, ')');
  WriteLn(AIrFile, '  unreachable');
  WriteLn(AIrFile, '}');
end;

procedure TLlvmEmitter.EmitRuntimeMain(var AIrFile: Text);
var
  Index, BlockIdx, OpIdx: LongInt;
  Op: TMirOperation;
  Block: TMirBlock;
  WriteLines: TLLvmStringArray;
  ResultName, OpcodeName, CmpPred: string;

  function ValueLabel(const AValueId: TMirValueId): string;
  var
    V: TMirValue;
  begin
    V := FMirModel.GetValue(AValueId);
    if V.ConstHasValue then
      Result := IntToStr(V.ConstInt)
    else
      Result := '%v' + IntToStr(AValueId);
  end;

  function OperandText(const ARef: TMirOperandRef): string;
  begin
    case ARef.Kind of
      morkValue: Result := ValueLabel(ARef.ValueId);
      morkLiteralInt: Result := IntToStr(ARef.LiteralInt);
      morkBlockLabel: Result := '%' + FMirModel.BlockById(ARef.BlockId).LabelName;
      morkGlobal: Result := '@' + ARef.GlobalSymbol;
    else
      Result := '';
    end;
  end;

begin
  WriteLines := CollectWriteLines;
  EmitTargetHeader(AIrFile);
  EmitGlobalConstStrings(AIrFile, WriteLines);

  WriteLn(AIrFile);
  WriteLn(AIrFile, 'define void @_start() noreturn {');

  for BlockIdx := 0 to FMirModel.BlockCount - 1 do
  begin
    Block := FMirModel.BlockAt(BlockIdx);
    WriteLn(AIrFile, Block.LabelName, ':');
    for OpIdx := 0 to FMirModel.OperationCount - 1 do
    begin
      Op := FMirModel.OperationAt(OpIdx);
      if Op.BlockId <> Block.BlockId then
        Continue;
      if Op.Kind = 'alloca' then
      begin
        ResultName := ValueLabel(Op.ResultValueId);
        WriteLn(AIrFile, '  ', ResultName, ' = alloca i64');
      end
      else if Op.Kind = 'store' then
      begin
        if Length(Op.OperandRefs) >= 2 then
          WriteLn(AIrFile, '  store i64 ',
            OperandText(Op.OperandRefs[0]), ', ptr ',
            OperandText(Op.OperandRefs[1]));
      end
      else if Op.Kind = 'load' then
      begin
        ResultName := ValueLabel(Op.ResultValueId);
        if Length(Op.OperandRefs) >= 1 then
          WriteLn(AIrFile, '  ', ResultName, ' = load i64, ptr ',
            OperandText(Op.OperandRefs[0]));
      end
      else if (Op.Kind = 'add') or (Op.Kind = 'sub') or (Op.Kind = 'mul') then
      begin
        ResultName := ValueLabel(Op.ResultValueId);
        if Op.Kind = 'add' then
          OpcodeName := 'add'
        else if Op.Kind = 'sub' then
          OpcodeName := 'sub'
        else
          OpcodeName := 'mul';
        if Length(Op.OperandRefs) >= 2 then
          WriteLn(AIrFile, '  ', ResultName, ' = ', OpcodeName, ' i64 ',
            OperandText(Op.OperandRefs[0]), ', ',
            OperandText(Op.OperandRefs[1]));
      end
      else if (Op.Kind = 'icmp-eq') or (Op.Kind = 'icmp-ne') or
        (Op.Kind = 'icmp-slt') or (Op.Kind = 'icmp-sle') or
        (Op.Kind = 'icmp-sgt') or (Op.Kind = 'icmp-sge') then
      begin
        ResultName := ValueLabel(Op.ResultValueId);
        if Op.Kind = 'icmp-eq' then CmpPred := 'eq'
        else if Op.Kind = 'icmp-ne' then CmpPred := 'ne'
        else if Op.Kind = 'icmp-slt' then CmpPred := 'slt'
        else if Op.Kind = 'icmp-sle' then CmpPred := 'sle'
        else if Op.Kind = 'icmp-sgt' then CmpPred := 'sgt'
        else CmpPred := 'sge';
        if Length(Op.OperandRefs) >= 2 then
          WriteLn(AIrFile, '  ', ResultName, ' = icmp ', CmpPred, ' i64 ',
            OperandText(Op.OperandRefs[0]), ', ',
            OperandText(Op.OperandRefs[1]));
      end
      else if Op.Kind = 'br' then
      begin
        if Length(Op.OperandRefs) >= 1 then
          WriteLn(AIrFile, '  br label ',
            OperandText(Op.OperandRefs[0]));
      end
      else if Op.Kind = 'cond-br' then
      begin
        if Length(Op.OperandRefs) >= 3 then
          WriteLn(AIrFile, '  br i1 ',
            OperandText(Op.OperandRefs[0]), ', label ',
            OperandText(Op.OperandRefs[1]), ', label ',
            OperandText(Op.OperandRefs[2]));
      end
      else if Op.Kind = 'write-line' then
      begin
        for Index := 0 to High(WriteLines) do
          if WriteLines[Index] = Op.Operand then
          begin
            WriteLn(AIrFile,
              '  call void asm sideeffect "movq $$1, %rax; syscall", "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr @.str.',
              Index, ', i64 ', Length(WriteLines[Index]), ')');
            Break;
          end;
      end
      else if Op.Kind = 'runtime-halt' then
      begin
        if Length(Op.OperandRefs) >= 1 then
          WriteLn(AIrFile,
            '  call void asm sideeffect "movq $$60, %rax; syscall", "{rdi},~{rax},~{rcx},~{r11}"(i64 ',
            OperandText(Op.OperandRefs[0]), ')');
        WriteLn(AIrFile, '  unreachable');
      end;
    end;
  end;
  WriteLn(AIrFile, '}');
end;

function TLlvmEmitter.EmitToFile(const APath: string): Boolean;
var
  IrFile: Text;
begin
  Assign(IrFile, APath);
  {$I-}
  Rewrite(IrFile);
  {$I+}
  if IOResult <> 0 then
    Exit(False);

  try
    if (FMirModel <> nil) and FMirModel.HasRuntimeKinds then
      EmitRuntimeMain(IrFile)
    else
      EmitLegacyMain(IrFile);
  finally
    Close(IrFile);
  end;

  Result := IOResult = 0;
end;

end.
