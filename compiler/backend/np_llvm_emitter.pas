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
    function NeedsItoaHelper: Boolean;
    procedure EmitTargetHeader(var AIrFile: Text);
    procedure EmitGlobalConstStrings(
      var AIrFile: Text;
      const AWriteLines: TLLvmStringArray
    );
    procedure EmitItoaHelper(var AIrFile: Text);
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
  Index, J: LongInt;
  Op: TMirOperation;
  Seen: Boolean;
begin
  Result := nil;
  if FMirModel = nil then
    Exit;
  for Index := 0 to FMirModel.OperationCount - 1 do
  begin
    Op := FMirModel.OperationAt(Index);
    if Op.Kind <> 'write-line' then
      Continue;
    Seen := False;
    for J := 0 to High(Result) do
      if Result[J] = Op.Operand then
      begin
        Seen := True;
        Break;
      end;
    if Seen then
      Continue;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Op.Operand;
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

function TLlvmEmitter.NeedsItoaHelper: Boolean;
var
  Index: LongInt;
begin
  if FMirModel = nil then
    Exit(False);
  for Index := 0 to FMirModel.OperationCount - 1 do
    if FMirModel.OperationAt(Index).Kind = 'write-int' then
      Exit(True);
  Result := False;
end;

procedure TLlvmEmitter.EmitItoaHelper(var AIrFile: Text);
begin
  WriteLn(AIrFile);
  WriteLn(AIrFile, 'define internal void @write_i64_decimal(i64 %v) {');
  WriteLn(AIrFile, 'entry:');
  WriteLn(AIrFile, '  %buf = alloca [24 x i8]');
  WriteLn(AIrFile, '  %is_neg = icmp slt i64 %v, 0');
  WriteLn(AIrFile, '  %neg_v = sub i64 0, %v');
  WriteLn(AIrFile, '  %abs_v = select i1 %is_neg, i64 %neg_v, i64 %v');
  WriteLn(AIrFile, '  %end_ptr = getelementptr [24 x i8], ptr %buf, i64 0, i64 24');
  WriteLn(AIrFile, '  %first_ptr = getelementptr [24 x i8], ptr %buf, i64 0, i64 23');
  WriteLn(AIrFile, '  br label %loop');
  WriteLn(AIrFile, 'loop:');
  WriteLn(AIrFile, '  %cur = phi i64 [ %abs_v, %entry ], [ %nxt, %loop ]');
  WriteLn(AIrFile, '  %ptr = phi ptr [ %first_ptr, %entry ], [ %ptr_prev, %loop ]');
  WriteLn(AIrFile, '  %digit = urem i64 %cur, 10');
  WriteLn(AIrFile, '  %digit_i8 = trunc i64 %digit to i8');
  WriteLn(AIrFile, '  %digit_ascii = add i8 %digit_i8, 48');
  WriteLn(AIrFile, '  store i8 %digit_ascii, ptr %ptr');
  WriteLn(AIrFile, '  %nxt = udiv i64 %cur, 10');
  WriteLn(AIrFile, '  %ptr_prev = getelementptr i8, ptr %ptr, i64 -1');
  WriteLn(AIrFile, '  %done = icmp eq i64 %nxt, 0');
  WriteLn(AIrFile, '  br i1 %done, label %neg_check, label %loop');
  WriteLn(AIrFile, 'neg_check:');
  WriteLn(AIrFile, '  br i1 %is_neg, label %put_minus, label %finish');
  WriteLn(AIrFile, 'put_minus:');
  WriteLn(AIrFile, '  store i8 45, ptr %ptr_prev');
  WriteLn(AIrFile, '  %ptr_minus_prev = getelementptr i8, ptr %ptr_prev, i64 -1');
  WriteLn(AIrFile, '  br label %finish');
  WriteLn(AIrFile, 'finish:');
  WriteLn(AIrFile, '  %start_ptr = phi ptr [ %ptr_prev, %neg_check ], [ %ptr_minus_prev, %put_minus ]');
  WriteLn(AIrFile, '  %first_byte = getelementptr i8, ptr %start_ptr, i64 1');
  WriteLn(AIrFile, '  %end_addr = ptrtoint ptr %end_ptr to i64');
  WriteLn(AIrFile, '  %first_addr = ptrtoint ptr %first_byte to i64');
  WriteLn(AIrFile, '  %nbytes = sub i64 %end_addr, %first_addr');
  WriteLn(AIrFile, '  call void asm sideeffect "movq $$1, %rax; syscall", "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr %first_byte, i64 %nbytes)');
  WriteLn(AIrFile, '  ret void');
  WriteLn(AIrFile, '}');
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
  if NeedsItoaHelper then
    EmitItoaHelper(AIrFile);

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
      else if Op.Kind = 'write-int' then
      begin
        if Length(Op.OperandRefs) >= 1 then
          WriteLn(AIrFile, '  call void @write_i64_decimal(i64 ',
            OperandText(Op.OperandRefs[0]), ')');
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
