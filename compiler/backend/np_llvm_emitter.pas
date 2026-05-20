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
    FWriteLines: TLLvmStringArray;
    procedure EmitBlockOps(var AIrFile: Text; const ABlockId: LongInt;
      const AAllocaOnly: Boolean);
    function ResolveExitCode: LongInt;
    function CollectWriteLines: TLLvmStringArray;
    function EscapeLLVMString(const AValue: string): string;
    function NeedsItoaHelper: Boolean;
    function NeedsStrConcatHelper: Boolean;
    procedure EmitTargetHeader(var AIrFile: Text);
    procedure EmitGlobalConstStrings(
      var AIrFile: Text;
      const AWriteLines: TLLvmStringArray
    );
    procedure EmitItoaHelper(var AIrFile: Text);
    procedure EmitStrConcatHelper(var AIrFile: Text);
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

procedure TLlvmEmitter.EmitBlockOps(var AIrFile: Text;
  const ABlockId: LongInt; const AAllocaOnly: Boolean);
var
  OpIdx, I, LlvmArgIdx: LongInt;
  Op: TMirOperation;
  ResultName, OpcodeName, CmpPred: string;

  function ValueLabel(const AValueId: TMirValueId): string;
  var V: TMirValue;
  begin
    V := FMirModel.GetValue(AValueId);
    if V.ConstHasValue then Result := IntToStr(V.ConstInt)
    else Result := '%v' + IntToStr(AValueId);
  end;

  function OperandText(const ARef: TMirOperandRef): string;
  begin
    case ARef.Kind of
      morkValue: Result := ValueLabel(ARef.ValueId);
      morkLiteralInt: Result := IntToStr(ARef.LiteralInt);
      morkBlockLabel: Result := '%' + FMirModel.BlockById(ARef.BlockId).LabelName;
      morkGlobal: Result := '@' + ARef.GlobalSymbol;
    else Result := '';
    end;
  end;

begin
  for OpIdx := 0 to FMirModel.OperationCount - 1 do
  begin
    Op := FMirModel.OperationAt(OpIdx);
    if Op.BlockId <> ABlockId then
      Continue;
    if AAllocaOnly then
    begin
      if Op.Kind = 'alloca' then
        WriteLn(AIrFile, '  ', ValueLabel(Op.ResultValueId), ' = alloca i64')
      else if Op.Kind = 'alloca-ptr' then
        WriteLn(AIrFile, '  ', ValueLabel(Op.ResultValueId), ' = alloca ptr');
      Continue;
    end;
    if (Op.Kind = 'alloca') or (Op.Kind = 'alloca-ptr') then
      Continue;
    if Op.Kind = 'store' then
    begin
      if Length(Op.OperandRefs) >= 2 then
        WriteLn(AIrFile, '  store i64 ', OperandText(Op.OperandRefs[0]),
          ', ptr ', OperandText(Op.OperandRefs[1]));
    end
    else if Op.Kind = 'store-ptr' then
    begin
      if Length(Op.OperandRefs) >= 2 then
        WriteLn(AIrFile, '  store ptr ', OperandText(Op.OperandRefs[0]),
          ', ptr ', OperandText(Op.OperandRefs[1]));
    end
    else if Op.Kind = 'load' then
    begin
      ResultName := ValueLabel(Op.ResultValueId);
      if Length(Op.OperandRefs) >= 1 then
        WriteLn(AIrFile, '  ', ResultName, ' = load i64, ptr ',
          OperandText(Op.OperandRefs[0]));
    end
    else if Op.Kind = 'load-ptr' then
    begin
      ResultName := ValueLabel(Op.ResultValueId);
      if Length(Op.OperandRefs) >= 1 then
        WriteLn(AIrFile, '  ', ResultName, ' = load ptr, ptr ',
          OperandText(Op.OperandRefs[0]));
    end
    else if (Op.Kind = 'add') or (Op.Kind = 'sub') or (Op.Kind = 'mul') or
      (Op.Kind = 'div') or (Op.Kind = 'mod') then
    begin
      ResultName := ValueLabel(Op.ResultValueId);
      if Op.Kind = 'add' then OpcodeName := 'add'
      else if Op.Kind = 'sub' then OpcodeName := 'sub'
      else if Op.Kind = 'mul' then OpcodeName := 'mul'
      else if Op.Kind = 'div' then OpcodeName := 'sdiv'
      else OpcodeName := 'srem';
      if Length(Op.OperandRefs) >= 2 then
        WriteLn(AIrFile, '  ', ResultName, ' = ', OpcodeName, ' i64 ',
          OperandText(Op.OperandRefs[0]), ', ', OperandText(Op.OperandRefs[1]));
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
          OperandText(Op.OperandRefs[0]), ', ', OperandText(Op.OperandRefs[1]));
    end
    else if Op.Kind = 'br' then
    begin
      if Length(Op.OperandRefs) >= 1 then
        WriteLn(AIrFile, '  br label ', OperandText(Op.OperandRefs[0]));
    end
    else if Op.Kind = 'cond-br' then
    begin
      if Length(Op.OperandRefs) >= 3 then
        WriteLn(AIrFile, '  br i1 ', OperandText(Op.OperandRefs[0]),
          ', label ', OperandText(Op.OperandRefs[1]),
          ', label ', OperandText(Op.OperandRefs[2]));
    end
    else if Op.Kind = 'call' then
    begin
      ResultName := ValueLabel(Op.ResultValueId);
      if Op.ResultValueId > 0 then
      begin
        Write(AIrFile, '  ', ResultName, ' = call i64 @', Op.Operand, '(');
        LlvmArgIdx := 0;
        for I := 0 to Length(Op.OperandRefs) - 1 do
        begin
          if LlvmArgIdx > 0 then Write(AIrFile, ', ');
          if FMirModel.GetValue(Op.OperandRefs[I].ValueId).TypeKind = mtkPtr then
            Write(AIrFile, 'ptr ', OperandText(Op.OperandRefs[I]))
          else
            Write(AIrFile, 'i64 ', OperandText(Op.OperandRefs[I]));
          Inc(LlvmArgIdx);
        end;
        WriteLn(AIrFile, ')');
      end
      else
      begin
        Write(AIrFile, '  call void @', Op.Operand, '(');
        LlvmArgIdx := 0;
        for I := 0 to Length(Op.OperandRefs) - 1 do
        begin
          if LlvmArgIdx > 0 then Write(AIrFile, ', ');
          if FMirModel.GetValue(Op.OperandRefs[I].ValueId).TypeKind = mtkPtr then
            Write(AIrFile, 'ptr ', OperandText(Op.OperandRefs[I]))
          else
            Write(AIrFile, 'i64 ', OperandText(Op.OperandRefs[I]));
          Inc(LlvmArgIdx);
        end;
        WriteLn(AIrFile, ')');
      end;
    end
    else if Op.Kind = 'ret-i64' then
    begin
      if Length(Op.OperandRefs) >= 1 then
        WriteLn(AIrFile, '  ret i64 ', OperandText(Op.OperandRefs[0]))
      else
        WriteLn(AIrFile, '  ret i64 0');
    end
    else if Op.Kind = 'ret-void' then
      WriteLn(AIrFile, '  ret void')
    else if Op.Kind = 'ret-str' then
    begin
      if Length(Op.OperandRefs) >= 2 then
      begin
        ResultName := '%retstr.' + IntToStr(Op.OperationId);
        WriteLn(AIrFile, '  ', ResultName, '.p = load ptr, ptr ',
          OperandText(Op.OperandRefs[0]));
        WriteLn(AIrFile, '  ', ResultName, '.l = load i64, ptr ',
          OperandText(Op.OperandRefs[1]));
        WriteLn(AIrFile, '  ', ResultName,
          '.1 = insertvalue {ptr, i64} undef, ptr ', ResultName, '.p, 0');
        WriteLn(AIrFile, '  ', ResultName,
          '.2 = insertvalue {ptr, i64} ', ResultName, '.1, i64 ',
          ResultName, '.l, 1');
        WriteLn(AIrFile, '  ret {ptr, i64} ', ResultName, '.2');
      end;
    end
    else if Op.Kind = 'call-str' then
    begin
      if Length(Op.OperandRefs) >= 2 then
      begin
        ResultName := '%callstr.' + IntToStr(Op.OperationId);
        Write(AIrFile, '  ', ResultName, ' = call {ptr, i64} @', Op.Operand, '(');
        LlvmArgIdx := 0;
        for I := 2 to Length(Op.OperandRefs) - 1 do
        begin
          if LlvmArgIdx > 0 then Write(AIrFile, ', ');
          if FMirModel.GetValue(Op.OperandRefs[I].ValueId).TypeKind = mtkPtr then
            Write(AIrFile, 'ptr ', OperandText(Op.OperandRefs[I]))
          else
            Write(AIrFile, 'i64 ', OperandText(Op.OperandRefs[I]));
          Inc(LlvmArgIdx);
        end;
        WriteLn(AIrFile, ')');
        WriteLn(AIrFile, '  ', ResultName,
          '.p = extractvalue {ptr, i64} ', ResultName, ', 0');
        WriteLn(AIrFile, '  ', ResultName,
          '.l = extractvalue {ptr, i64} ', ResultName, ', 1');
        WriteLn(AIrFile, '  store ptr ', ResultName, '.p, ptr ',
          OperandText(Op.OperandRefs[0]));
        WriteLn(AIrFile, '  store i64 ', ResultName, '.l, ptr ',
          OperandText(Op.OperandRefs[1]));
      end;
    end
    else if Op.Kind = 'zext' then
    begin
      ResultName := ValueLabel(Op.ResultValueId);
      if Length(Op.OperandRefs) >= 1 then
        WriteLn(AIrFile, '  ', ResultName, ' = zext i1 ',
          OperandText(Op.OperandRefs[0]), ' to i64');
    end
    else if Op.Kind = 'write-line' then
    begin
      for I := 0 to Length(FWriteLines) - 1 do
        if FWriteLines[I] = Op.Operand then
        begin
          WriteLn(AIrFile,
            '  call void asm sideeffect "movq $$1, %rax; syscall", "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr @.str.',
            I, ', i64 ', Length(Op.Operand), ')');
          Break;
        end;
    end
    else if Op.Kind = 'write-int' then
    begin
      if Length(Op.OperandRefs) >= 1 then
        WriteLn(AIrFile, '  call void @write_i64_decimal(i64 ',
          OperandText(Op.OperandRefs[0]), ')');
    end
    else if Op.Kind = 'write-str-var' then
    begin
      if Length(Op.OperandRefs) >= 2 then
        WriteLn(AIrFile,
          '  call void asm sideeffect "movq $$1, %rax; syscall", "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr ',
          OperandText(Op.OperandRefs[0]), ', i64 ',
          OperandText(Op.OperandRefs[1]), ')');
    end
    else if Op.Kind = 'store-str' then
    begin
      if Length(Op.OperandRefs) >= 2 then
        for I := 0 to Length(FWriteLines) - 1 do
          if FWriteLines[I] = Op.Operand then
          begin
            WriteLn(AIrFile, '  store ptr @.str.', I, ', ptr ',
              OperandText(Op.OperandRefs[0]));
            WriteLn(AIrFile, '  store i64 ', Length(Op.Operand),
              ', ptr ', OperandText(Op.OperandRefs[1]));
            Break;
          end;
    end
    else if Op.Kind = 'str-concat' then
    begin
      if Length(Op.OperandRefs) >= 4 then
      begin
        ResultName := ValueLabel(Op.ResultValueId);
        WriteLn(AIrFile, '  ', ResultName,
          ' = call {ptr, i64} @np_str_concat(ptr ',
          OperandText(Op.OperandRefs[0]), ', i64 ',
          OperandText(Op.OperandRefs[1]), ', ptr ',
          OperandText(Op.OperandRefs[2]), ', i64 ',
          OperandText(Op.OperandRefs[3]), ')');
      end;
    end
    else if Op.Kind = 'extractvalue-ptr' then
    begin
      ResultName := ValueLabel(Op.ResultValueId);
      if Length(Op.OperandRefs) >= 1 then
        WriteLn(AIrFile, '  ', ResultName,
          ' = extractvalue {ptr, i64} ',
          OperandText(Op.OperandRefs[0]), ', 0');
    end
    else if Op.Kind = 'extractvalue-i64' then
    begin
      ResultName := ValueLabel(Op.ResultValueId);
      if Length(Op.OperandRefs) >= 1 then
        WriteLn(AIrFile, '  ', ResultName,
          ' = extractvalue {ptr, i64} ',
          OperandText(Op.OperandRefs[0]), ', 1');
    end
    else if Op.Kind = 'setlength-arr' then
    begin
      if Length(Op.OperandRefs) >= 2 then
      begin
        ResultName := '%arr.alloc.' + Op.DisplayName;
        WriteLn(AIrFile, '  ', ResultName, '.bytes = mul i64 ',
          OperandText(Op.OperandRefs[1]), ', 8');
        WriteLn(AIrFile, '  ', ResultName,
          ' = call ptr @np_alloc(i64 ', ResultName, '.bytes)');
        WriteLn(AIrFile, '  store ptr ', ResultName, ', ptr ',
          OperandText(Op.OperandRefs[0]));
      end;
    end
    else if Op.Kind = 'arr-store' then
    begin
      if Length(Op.OperandRefs) >= 3 then
      begin
        ResultName := '%arr.st.' + Op.DisplayName + '.' +
          IntToStr(Op.OperationId);
        WriteLn(AIrFile, '  ', ResultName, '.base = load ptr, ptr ',
          OperandText(Op.OperandRefs[0]));
        WriteLn(AIrFile, '  ', ResultName,
          '.ep = getelementptr i64, ptr ', ResultName, '.base, i64 ',
          OperandText(Op.OperandRefs[1]));
        WriteLn(AIrFile, '  store i64 ',
          OperandText(Op.OperandRefs[2]), ', ptr ', ResultName, '.ep');
      end;
    end
    else if Op.Kind = 'arr-load' then
    begin
      if Length(Op.OperandRefs) >= 2 then
      begin
        ResultName := ValueLabel(Op.ResultValueId);
        WriteLn(AIrFile, '  ', ResultName, '.base = load ptr, ptr ',
          OperandText(Op.OperandRefs[0]));
        WriteLn(AIrFile, '  ', ResultName,
          '.ep = getelementptr i64, ptr ', ResultName, '.base, i64 ',
          OperandText(Op.OperandRefs[1]));
        WriteLn(AIrFile, '  ', ResultName, ' = load i64, ptr ',
          ResultName, '.ep');
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
    if (Op.Kind <> 'write-line') and (Op.Kind <> 'store-str') then
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
        Result := Result + '\' + HexStr(Ord(AValue[Index]), 2)
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

function TLlvmEmitter.NeedsStrConcatHelper: Boolean;
var
  Index: LongInt;
begin
  if FMirModel = nil then
    Exit(False);
  for Index := 0 to FMirModel.OperationCount - 1 do
    if (FMirModel.OperationAt(Index).Kind = 'str-concat') or
      (FMirModel.OperationAt(Index).Kind = 'setlength-arr') then
      Exit(True);
  Result := False;
end;

procedure TLlvmEmitter.EmitStrConcatHelper(var AIrFile: Text);
begin
  WriteLn(AIrFile);
  WriteLn(AIrFile, '@__heap_cur = internal global ptr null');
  WriteLn(AIrFile);
  WriteLn(AIrFile, 'define internal ptr @np_alloc(i64 %size) {');
  WriteLn(AIrFile, 'entry:');
  WriteLn(AIrFile, '  %cur = load ptr, ptr @__heap_cur');
  WriteLn(AIrFile, '  %is_null = icmp eq ptr %cur, null');
  WriteLn(AIrFile, '  br i1 %is_null, label %init, label %alloc');
  WriteLn(AIrFile, 'init:');
  WriteLn(AIrFile, '  %brk0 = call i64 asm sideeffect "movq $$12, %rax\0Axorq %rdi, %rdi\0Asyscall", "={rax},~{rcx},~{r11},~{rdi}"()');
  WriteLn(AIrFile, '  %brk0p = inttoptr i64 %brk0 to ptr');
  WriteLn(AIrFile, '  store ptr %brk0p, ptr @__heap_cur');
  WriteLn(AIrFile, '  br label %alloc');
  WriteLn(AIrFile, 'alloc:');
  WriteLn(AIrFile, '  %base = load ptr, ptr @__heap_cur');
  WriteLn(AIrFile, '  %next = getelementptr i8, ptr %base, i64 %size');
  WriteLn(AIrFile, '  %nexti = ptrtoint ptr %next to i64');
  WriteLn(AIrFile, '  call i64 asm sideeffect "movq $$12, %rax\0Asyscall", "={rax},{rdi},~{rcx},~{r11}"(i64 %nexti)');
  WriteLn(AIrFile, '  store ptr %next, ptr @__heap_cur');
  WriteLn(AIrFile, '  ret ptr %base');
  WriteLn(AIrFile, '}');
  WriteLn(AIrFile);
  WriteLn(AIrFile, 'define internal void @np_memcpy(ptr %dst, ptr %src, i64 %n) {');
  WriteLn(AIrFile, 'entry:');
  WriteLn(AIrFile, '  %cmp0 = icmp eq i64 %n, 0');
  WriteLn(AIrFile, '  br i1 %cmp0, label %done, label %loop');
  WriteLn(AIrFile, 'loop:');
  WriteLn(AIrFile, '  %i = phi i64 [ 0, %entry ], [ %i_next, %loop ]');
  WriteLn(AIrFile, '  %sp = getelementptr i8, ptr %src, i64 %i');
  WriteLn(AIrFile, '  %b = load i8, ptr %sp');
  WriteLn(AIrFile, '  %dp = getelementptr i8, ptr %dst, i64 %i');
  WriteLn(AIrFile, '  store i8 %b, ptr %dp');
  WriteLn(AIrFile, '  %i_next = add i64 %i, 1');
  WriteLn(AIrFile, '  %cond = icmp eq i64 %i_next, %n');
  WriteLn(AIrFile, '  br i1 %cond, label %done, label %loop');
  WriteLn(AIrFile, 'done:');
  WriteLn(AIrFile, '  ret void');
  WriteLn(AIrFile, '}');
  WriteLn(AIrFile);
  WriteLn(AIrFile, 'define internal {ptr, i64} @np_str_concat(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len) {');
  WriteLn(AIrFile, 'entry:');
  WriteLn(AIrFile, '  %total = add i64 %a_len, %b_len');
  WriteLn(AIrFile, '  %buf = call ptr @np_alloc(i64 %total)');
  WriteLn(AIrFile, '  call void @np_memcpy(ptr %buf, ptr %a_ptr, i64 %a_len)');
  WriteLn(AIrFile, '  %dst2 = getelementptr i8, ptr %buf, i64 %a_len');
  WriteLn(AIrFile, '  call void @np_memcpy(ptr %dst2, ptr %b_ptr, i64 %b_len)');
  WriteLn(AIrFile, '  %r1 = insertvalue {ptr, i64} undef, ptr %buf, 0');
  WriteLn(AIrFile, '  %r2 = insertvalue {ptr, i64} %r1, i64 %total, 1');
  WriteLn(AIrFile, '  ret {ptr, i64} %r2');
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
  Index, BlockIdx, OpIdx, TabIdx, LlvmArgIdx: LongInt;
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
  FWriteLines := WriteLines;
  EmitTargetHeader(AIrFile);
  EmitGlobalConstStrings(AIrFile, WriteLines);
  if NeedsItoaHelper then
    EmitItoaHelper(AIrFile);
  if NeedsStrConcatHelper then
    EmitStrConcatHelper(AIrFile);

  for Index := 0 to FMirModel.FunctionCount - 1 do
  begin
    WriteLn(AIrFile);
    if FMirModel.FunctionAt(Index).ReturnType = 's' then
      Write(AIrFile, 'define {ptr, i64} @', FMirModel.FunctionAt(Index).Name, '(')
    else
      Write(AIrFile, 'define i64 @', FMirModel.FunctionAt(Index).Name, '(');
    LlvmArgIdx := 0;
    for OpIdx := 0 to FMirModel.FunctionAt(Index).ParamCount - 1 do
    begin
      if LlvmArgIdx > 0 then
        Write(AIrFile, ', ');
      if (OpIdx < Length(FMirModel.FunctionAt(Index).ParamTypes)) and
        (FMirModel.FunctionAt(Index).ParamTypes[OpIdx + 1] = 's') then
      begin
        Write(AIrFile, 'ptr %arg', LlvmArgIdx, ', i64 %arg', LlvmArgIdx + 1);
        Inc(LlvmArgIdx, 2);
      end
      else
      begin
        Write(AIrFile, 'i64 %arg', LlvmArgIdx);
        Inc(LlvmArgIdx);
      end;
    end;
    WriteLn(AIrFile, ') {');

    for BlockIdx := 0 to FMirModel.BlockCount - 1 do
    begin
      Block := FMirModel.BlockAt(BlockIdx);
      if Block.BlockId < FMirModel.FunctionAt(Index).EntryBlockId then
        Continue;
      if (Index < FMirModel.FunctionCount - 1) and
        (Block.BlockId >= FMirModel.FunctionAt(Index + 1).EntryBlockId) then
        Continue;
      WriteLn(AIrFile, Block.LabelName, ':');
      if Block.BlockId = FMirModel.FunctionAt(Index).EntryBlockId then
      begin
        EmitBlockOps(AIrFile, Block.BlockId, True);
        TabIdx := 0;
        LlvmArgIdx := 0;
        for OpIdx := 0 to FMirModel.OperationCount - 1 do
        begin
          Op := FMirModel.OperationAt(OpIdx);
          if Op.BlockId <> Block.BlockId then
            Continue;
          if (Op.Kind <> 'alloca') and (Op.Kind <> 'alloca-ptr') then
            Continue;
          if TabIdx >= FMirModel.FunctionAt(Index).ParamCount then
          begin
            Inc(TabIdx);
            Continue;
          end;
          if (TabIdx < Length(FMirModel.FunctionAt(Index).ParamTypes)) and
            (FMirModel.FunctionAt(Index).ParamTypes[TabIdx + 1] = 's') then
          begin
            if Op.Kind = 'alloca-ptr' then
              WriteLn(AIrFile, '  store ptr %arg', LlvmArgIdx,
                ', ptr %v', Op.ResultValueId)
            else
            begin
              WriteLn(AIrFile, '  store i64 %arg', LlvmArgIdx + 1,
                ', ptr %v', Op.ResultValueId);
              Inc(TabIdx);
              Inc(LlvmArgIdx, 2);
            end;
          end
          else
          begin
            WriteLn(AIrFile, '  store i64 %arg', LlvmArgIdx,
              ', ptr %v', Op.ResultValueId);
            Inc(TabIdx);
            Inc(LlvmArgIdx);
          end;
        end;
      end;
      EmitBlockOps(AIrFile, Block.BlockId, False);
    end;
    WriteLn(AIrFile, '}');
  end;

  WriteLn(AIrFile);
  WriteLn(AIrFile, 'define void @_start() noreturn {');

  for BlockIdx := 0 to FMirModel.BlockCount - 1 do
  begin
    Block := FMirModel.BlockAt(BlockIdx);
    if (FMirModel.FunctionCount > 0) and
      (Block.BlockId >= FMirModel.FunctionAt(0).EntryBlockId) then
      Continue;
    WriteLn(AIrFile, Block.LabelName, ':');
    EmitBlockOps(AIrFile, Block.BlockId, True);
    EmitBlockOps(AIrFile, Block.BlockId, False);
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
