unit np_hir_llvm_emitter;

{$mode objfpc}{$H+}

interface

uses
  np_hir_types, np_hir_model;

type
  THIRLlvmEmitter = class
  private
    FModule: THIRModule;
    FLines: array of string;
    FLineCount: LongInt;
    FNeedsWriteInt: Boolean;
    FNeedsStrConcat: Boolean;
    FStrConstants: array of string;
    FStrConstCount: LongInt;
    procedure Emit(const S: string);
    function TypeToLlvm(ATypeId: THIRTypeId): string;
    function AddStrConstant(const AValue: string): LongInt;
    function EscapeLlvmStr(const AValue: string): string;
    procedure EmitFunction(const AFunc: THIRFunction);
    procedure EmitInstr(const AInstr: THIRInstr);
    procedure EmitTerminator(const ATerm: THIRTerminator);
    procedure EmitWriteIntHelper;
    procedure EmitStrConstants;
    procedure EmitStrConcatHelper;
  public
    constructor Create(AModule: THIRModule);
    procedure EmitModule;
    function AsText: string;
    procedure SaveToFile(const APath: string);
  end;

implementation

uses
  SysUtils;

constructor THIRLlvmEmitter.Create(AModule: THIRModule);
begin
  inherited Create;
  FModule := AModule;
  FLineCount := 0;
  FNeedsWriteInt := False;
  FNeedsStrConcat := False;
  SetLength(FLines, 0);
end;

procedure THIRLlvmEmitter.Emit(const S: string);
begin
  if FLineCount >= Length(FLines) then
    SetLength(FLines, FLineCount + 128);
  FLines[FLineCount] := S;
  Inc(FLineCount);
end;

function THIRLlvmEmitter.TypeToLlvm(ATypeId: THIRTypeId): string;
var
  T: THIRTypeRec;
begin
  if ATypeId = 0 then Exit('void');
  T := FModule.Types.GetType(ATypeId);
  case T.Kind of
    htkVoid: Result := 'void';
    htkBool: Result := 'i1';
    htkInt: Result := 'i' + IntToStr(T.BitWidth);
    htkFloat:
      case T.FloatWidth of
        fwF32: Result := 'float';
        fwF64: Result := 'double';
        fwF80: Result := 'x86_fp80';
      end;
    htkPointer, htkUntypedPtr: Result := 'ptr';
    htkString: Result := 'ptr';
  else
    Result := 'i64';
  end;
end;

procedure THIRLlvmEmitter.EmitInstr(const AInstr: THIRInstr);
var
  LlvmType, Op: string;
  I: LongInt;
begin
  LlvmType := TypeToLlvm(AInstr.TypeId);

  case AInstr.Kind of
    hikAlloca:
      Emit('  %' + IntToStr(AInstr.ResultId) + ' = alloca ' + LlvmType);
    hikLoad:
    begin
      if AInstr.IntrinsicName <> '' then
      begin
        if Copy(AInstr.IntrinsicName, 1, 6) = 'const:' then
          Emit('  %' + IntToStr(AInstr.ResultId) + ' = add ' + LlvmType +
            ' ' + Copy(AInstr.IntrinsicName, 7, Length(AInstr.IntrinsicName)) + ', 0')
        else if Length(AInstr.Operands) > 0 then
          Emit('  %' + IntToStr(AInstr.ResultId) + ' = load ' + LlvmType +
            ', ptr %' + IntToStr(AInstr.Operands[0].ValueId))
        else
          Emit('  %' + IntToStr(AInstr.ResultId) + ' = load ' + LlvmType + ', ptr null');
      end
      else if Length(AInstr.Operands) > 0 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = load ' + LlvmType +
          ', ptr %' + IntToStr(AInstr.Operands[0].ValueId))
      else
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = load ' + LlvmType + ', ptr null');
    end;
    hikStore:
      if Length(AInstr.Operands) >= 2 then
        Emit('  store ' + LlvmType + ' %' + IntToStr(AInstr.Operands[0].ValueId) +
          ', ptr %' + IntToStr(AInstr.Operands[1].ValueId));
    hikAdd:
      if Length(AInstr.Operands) >= 2 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = add ' + LlvmType +
          ' %' + IntToStr(AInstr.Operands[0].ValueId) +
          ', %' + IntToStr(AInstr.Operands[1].ValueId));
    hikSub:
      if Length(AInstr.Operands) >= 2 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = sub ' + LlvmType +
          ' %' + IntToStr(AInstr.Operands[0].ValueId) +
          ', %' + IntToStr(AInstr.Operands[1].ValueId));
    hikMul:
      if Length(AInstr.Operands) >= 2 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = mul ' + LlvmType +
          ' %' + IntToStr(AInstr.Operands[0].ValueId) +
          ', %' + IntToStr(AInstr.Operands[1].ValueId));
    hikDiv:
      if Length(AInstr.Operands) >= 2 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = sdiv ' + LlvmType +
          ' %' + IntToStr(AInstr.Operands[0].ValueId) +
          ', %' + IntToStr(AInstr.Operands[1].ValueId));
    hikMod:
      if Length(AInstr.Operands) >= 2 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = srem ' + LlvmType +
          ' %' + IntToStr(AInstr.Operands[0].ValueId) +
          ', %' + IntToStr(AInstr.Operands[1].ValueId));
    hikNeg:
      if Length(AInstr.Operands) >= 1 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = sub ' + LlvmType +
          ' 0, %' + IntToStr(AInstr.Operands[0].ValueId));
    hikCmpEq, hikCmpNe, hikCmpLt, hikCmpLe, hikCmpGt, hikCmpGe:
    begin
      case AInstr.Kind of
        hikCmpEq: Op := 'eq';
        hikCmpNe: Op := 'ne';
        hikCmpLt: Op := 'slt';
        hikCmpLe: Op := 'sle';
        hikCmpGt: Op := 'sgt';
        hikCmpGe: Op := 'sge';
      end;
      if Length(AInstr.Operands) >= 2 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = icmp ' + Op + ' i64' +
          ' %' + IntToStr(AInstr.Operands[0].ValueId) +
          ', %' + IntToStr(AInstr.Operands[1].ValueId));
    end;
    hikZext:
      if Length(AInstr.Operands) >= 1 then
        Emit('  %' + IntToStr(AInstr.ResultId) + ' = zext i1 %' +
          IntToStr(AInstr.Operands[0].ValueId) + ' to i64');
    hikCall:
    begin
      Op := '  %' + IntToStr(AInstr.ResultId) + ' = call ' + LlvmType +
        ' @' + AInstr.CallTarget + '(';
      for I := 0 to High(AInstr.Operands) do
      begin
        if I > 0 then Op := Op + ', ';
        if AInstr.Operands[I].TypeId <> 0 then
          Op := Op + TypeToLlvm(AInstr.Operands[I].TypeId) + ' %' +
            IntToStr(AInstr.Operands[I].ValueId)
        else
          Op := Op + 'i64 %' + IntToStr(AInstr.Operands[I].ValueId);
      end;
      Op := Op + ')';
      Emit(Op);
    end;
    hikIntrinsic:
    begin
      if AInstr.IntrinsicName = 'halt' then
      begin
        if AInstr.CallTarget <> '' then
          Emit('  call void asm sideeffect "movq $$60, %rax; syscall",' +
            ' "{rdi},~{rax},~{rcx},~{r11}"(i64 ' + AInstr.CallTarget + ')')
        else if Length(AInstr.Operands) >= 1 then
          Emit('  call void asm sideeffect "movq $$60, %rax; syscall",' +
            ' "{rdi},~{rax},~{rcx},~{r11}"(i64 %' +
            IntToStr(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'write_int' then
      begin
        FNeedsWriteInt := True;
        if Length(AInstr.Operands) >= 1 then
          Emit('  call void @write_i64_decimal(i64 %' +
            IntToStr(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'write_str' then
      begin
        I := AddStrConstant(AInstr.CallTarget);
        Emit('  call void asm sideeffect "movq $$1, %rax; syscall",' +
          ' "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr @.str.' +
          IntToStr(I) + ', i64 ' + IntToStr(Length(AInstr.CallTarget)) + ')');
      end
      else if AInstr.IntrinsicName = 'write_str_var' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Emit('  call void asm sideeffect "movq $$1, %rax; syscall",' +
            ' "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr %' +
            IntToStr(AInstr.Operands[0].ValueId) + ', i64 %' +
            IntToStr(AInstr.Operands[1].ValueId) + ')');
        end;
      end
      else if AInstr.IntrinsicName = 'store_str_lit' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          I := AddStrConstant(AInstr.CallTarget);
          Emit('  store ptr @.str.' + IntToStr(I) + ', ptr %' +
            IntToStr(AInstr.Operands[0].ValueId));
          Emit('  store i64 ' + IntToStr(Length(AInstr.CallTarget)) +
            ', ptr %' + IntToStr(AInstr.Operands[1].ValueId));
        end;
      end
      else if AInstr.IntrinsicName = 'call_str_func' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Op := '  %callstr.' + IntToStr(AInstr.ResultId) +
            ' = call {ptr, i64} @' + AInstr.CallTarget + '(';
          for I := 2 to High(AInstr.Operands) do
          begin
            if I > 2 then Op := Op + ', ';
            if AInstr.Operands[I].TypeId <> 0 then
              Op := Op + TypeToLlvm(AInstr.Operands[I].TypeId) + ' %' +
                IntToStr(AInstr.Operands[I].ValueId)
            else
              Op := Op + 'i64 %' + IntToStr(AInstr.Operands[I].ValueId);
          end;
          Op := Op + ')';
          Emit(Op);
          Emit('  %callstr.' + IntToStr(AInstr.ResultId) +
            '.p = extractvalue {ptr, i64} %callstr.' +
            IntToStr(AInstr.ResultId) + ', 0');
          Emit('  %callstr.' + IntToStr(AInstr.ResultId) +
            '.l = extractvalue {ptr, i64} %callstr.' +
            IntToStr(AInstr.ResultId) + ', 1');
          Emit('  store ptr %callstr.' + IntToStr(AInstr.ResultId) +
            '.p, ptr %' + IntToStr(AInstr.Operands[0].ValueId));
          Emit('  store i64 %callstr.' + IntToStr(AInstr.ResultId) +
            '.l, ptr %' + IntToStr(AInstr.Operands[1].ValueId));
        end;
      end
      else if AInstr.IntrinsicName = 'str_concat' then
      begin
        FNeedsStrConcat := True;
        if Length(AInstr.Operands) >= 6 then
        begin
          Emit('  %concat.' + IntToStr(AInstr.ResultId) +
            ' = call {ptr, i64} @np_str_concat(ptr %' +
            IntToStr(AInstr.Operands[0].ValueId) + ', i64 %' +
            IntToStr(AInstr.Operands[1].ValueId) + ', ptr %' +
            IntToStr(AInstr.Operands[2].ValueId) + ', i64 %' +
            IntToStr(AInstr.Operands[3].ValueId) + ')');
          Emit('  %concat.' + IntToStr(AInstr.ResultId) +
            '.p = extractvalue {ptr, i64} %concat.' +
            IntToStr(AInstr.ResultId) + ', 0');
          Emit('  %concat.' + IntToStr(AInstr.ResultId) +
            '.l = extractvalue {ptr, i64} %concat.' +
            IntToStr(AInstr.ResultId) + ', 1');
          Emit('  store ptr %concat.' + IntToStr(AInstr.ResultId) +
            '.p, ptr %' + IntToStr(AInstr.Operands[4].ValueId));
          Emit('  store i64 %concat.' + IntToStr(AInstr.ResultId) +
            '.l, ptr %' + IntToStr(AInstr.Operands[5].ValueId));
        end;
      end
      else if AInstr.IntrinsicName = 'ret_str' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Emit('  %retstr.' + IntToStr(AInstr.ResultId) +
            '.1 = insertvalue {ptr, i64} undef, ptr %' +
            IntToStr(AInstr.Operands[0].ValueId) + ', 0');
          Emit('  %retstr.' + IntToStr(AInstr.ResultId) +
            '.2 = insertvalue {ptr, i64} %retstr.' +
            IntToStr(AInstr.ResultId) + '.1, i64 %' +
            IntToStr(AInstr.Operands[1].ValueId) + ', 1');
          Emit('  ret {ptr, i64} %retstr.' + IntToStr(AInstr.ResultId) + '.2');
        end;
      end
      else if AInstr.IntrinsicName = 'gep_i64' then
      begin
        if Length(AInstr.Operands) >= 2 then
          Emit('  %' + IntToStr(AInstr.ResultId) +
            ' = getelementptr i64, ptr %' +
            IntToStr(AInstr.Operands[0].ValueId) + ', i64 %' +
            IntToStr(AInstr.Operands[1].ValueId));
      end
      else if AInstr.IntrinsicName = 'arr_alloc' then
      begin
        FNeedsStrConcat := True;
        if Length(AInstr.Operands) >= 1 then
        begin
          Emit('  %arralloc.' + IntToStr(AInstr.ResultId) +
            '.sz = mul i64 %' + IntToStr(AInstr.Operands[0].ValueId) + ', 8');
          Emit('  %' + IntToStr(AInstr.ResultId) +
            ' = call ptr @np_alloc(i64 %arralloc.' +
            IntToStr(AInstr.ResultId) + '.sz)');
        end;
      end;
    end;
  end;
end;

procedure THIRLlvmEmitter.EmitTerminator(const ATerm: THIRTerminator);
begin
  case ATerm.Kind of
    htkReturn:
      if ATerm.ReturnValue = 0 then
        Emit('  ret void')
      else
        Emit('  ret i64 %' + IntToStr(ATerm.ReturnValue));
    htkBranch:
      Emit('  br label %bb' + IntToStr(ATerm.TargetBlock));
    htkCondBranch:
      Emit('  br i1 %' + IntToStr(ATerm.Condition) +
        ', label %bb' + IntToStr(ATerm.TrueBlock) +
        ', label %bb' + IntToStr(ATerm.FalseBlock));
    htkUnreachable:
      Emit('  unreachable');
  end;
end;

procedure THIRLlvmEmitter.EmitFunction(const AFunc: THIRFunction);
var
  I, J, K, MinIdx: LongInt;
  ParamStr, RetStr: string;
  Order: array of LongInt;
  MinVal, CurVal: LongInt;
  T: THIRTypeRec;
begin
  if AFunc.IsExternal then Exit;

  ParamStr := '';
  for I := 0 to High(AFunc.Params) do
  begin
    if I > 0 then ParamStr := ParamStr + ', ';
    ParamStr := ParamStr + TypeToLlvm(AFunc.Params[I].TypeId) +
      ' %' + IntToStr(AFunc.Params[I].ValueId);
  end;

  T := FModule.Types.GetType(AFunc.ReturnTypeId);
  if T.Kind = htkString then
    RetStr := '{ptr, i64}'
  else
    RetStr := TypeToLlvm(AFunc.ReturnTypeId);

  Emit('');
  Emit('define ' + RetStr + ' @' + AFunc.Name +
    '(' + ParamStr + ') {');

  SetLength(Order, Length(AFunc.Blocks));
  for I := 0 to High(Order) do
    Order[I] := I;
  for I := 0 to High(Order) - 1 do
  begin
    MinIdx := I;
    if Length(AFunc.Blocks[Order[MinIdx]].Instrs) > 0 then
      MinVal := AFunc.Blocks[Order[MinIdx]].Instrs[0].ResultId
    else
      MinVal := MaxInt;
    for K := I + 1 to High(Order) do
    begin
      if Length(AFunc.Blocks[Order[K]].Instrs) > 0 then
        CurVal := AFunc.Blocks[Order[K]].Instrs[0].ResultId
      else
        CurVal := MaxInt;
      if CurVal < MinVal then
      begin
        MinVal := CurVal;
        MinIdx := K;
      end;
    end;
    if MinIdx <> I then
    begin
      J := Order[I];
      Order[I] := Order[MinIdx];
      Order[MinIdx] := J;
    end;
  end;

  for I := 0 to High(Order) do
  begin
    Emit('bb' + IntToStr(AFunc.Blocks[Order[I]].Id) + ':');
    for J := 0 to High(AFunc.Blocks[Order[I]].Instrs) do
      EmitInstr(AFunc.Blocks[Order[I]].Instrs[J]);
    EmitTerminator(AFunc.Blocks[Order[I]].Terminator);
  end;

  Emit('}');
end;

procedure THIRLlvmEmitter.EmitModule;
var
  I: LongInt;
begin
  FLineCount := 0;
  FStrConstCount := 0;
  FNeedsWriteInt := False;
  FNeedsStrConcat := False;
  Emit('; ModuleID = ''' + FModule.ModuleName + '''');
  Emit('target triple = "x86_64-unknown-linux-gnu"');
  Emit('target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64"');

  for I := 0 to FModule.FunctionCount - 1 do
    EmitFunction(FModule.FunctionAt(I));

  if FStrConstCount > 0 then
  begin
    Emit('');
    EmitStrConstants;
  end;

  if FNeedsWriteInt then
    EmitWriteIntHelper;

  if FNeedsStrConcat then
    EmitStrConcatHelper;
end;

procedure THIRLlvmEmitter.EmitWriteIntHelper;
begin
  Emit('');
  Emit('define internal void @write_i64_decimal(i64 %v) {');
  Emit('entry:');
  Emit('  %buf = alloca [24 x i8]');
  Emit('  %is_neg = icmp slt i64 %v, 0');
  Emit('  %neg_v = sub i64 0, %v');
  Emit('  %abs_v = select i1 %is_neg, i64 %neg_v, i64 %v');
  Emit('  %end_ptr = getelementptr [24 x i8], ptr %buf, i64 0, i64 24');
  Emit('  %first_ptr = getelementptr [24 x i8], ptr %buf, i64 0, i64 23');
  Emit('  br label %loop');
  Emit('loop:');
  Emit('  %cur = phi i64 [ %abs_v, %entry ], [ %nxt, %loop ]');
  Emit('  %ptr = phi ptr [ %first_ptr, %entry ], [ %ptr_prev, %loop ]');
  Emit('  %digit = urem i64 %cur, 10');
  Emit('  %digit_i8 = trunc i64 %digit to i8');
  Emit('  %digit_ascii = add i8 %digit_i8, 48');
  Emit('  store i8 %digit_ascii, ptr %ptr');
  Emit('  %nxt = udiv i64 %cur, 10');
  Emit('  %ptr_prev = getelementptr i8, ptr %ptr, i64 -1');
  Emit('  %done = icmp eq i64 %nxt, 0');
  Emit('  br i1 %done, label %neg_check, label %loop');
  Emit('neg_check:');
  Emit('  br i1 %is_neg, label %put_minus, label %finish');
  Emit('put_minus:');
  Emit('  store i8 45, ptr %ptr_prev');
  Emit('  %ptr_minus_prev = getelementptr i8, ptr %ptr_prev, i64 -1');
  Emit('  br label %finish');
  Emit('finish:');
  Emit('  %start_ptr = phi ptr [ %ptr_prev, %neg_check ], [ %ptr_minus_prev, %put_minus ]');
  Emit('  %start_next = getelementptr i8, ptr %start_ptr, i64 1');
  Emit('  %len = ptrtoint ptr %end_ptr to i64');
  Emit('  %start_int = ptrtoint ptr %start_next to i64');
  Emit('  %write_len = sub i64 %len, %start_int');
  Emit('  call void asm sideeffect "movq $$1, %rax; syscall",' +
    ' "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr %start_next, i64 %write_len)');
  Emit('  ret void');
  Emit('}');
end;

function THIRLlvmEmitter.AddStrConstant(const AValue: string): LongInt;
begin
  Result := FStrConstCount;
  if FStrConstCount >= Length(FStrConstants) then
    SetLength(FStrConstants, FStrConstCount + 16);
  FStrConstants[FStrConstCount] := AValue;
  Inc(FStrConstCount);
end;

function THIRLlvmEmitter.EscapeLlvmStr(const AValue: string): string;
var
  I: LongInt;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(AValue) do
  begin
    C := AValue[I];
    if (Ord(C) < 32) or (Ord(C) > 126) or (C = '"') or (C = '\') then
      Result := Result + '\' + LowerCase(IntToHex(Ord(C), 2))
    else
      Result := Result + C;
  end;
end;

procedure THIRLlvmEmitter.EmitStrConstants;
var
  I, Len: LongInt;
begin
  for I := 0 to FStrConstCount - 1 do
  begin
    Len := Length(FStrConstants[I]);
    Emit('@.str.' + IntToStr(I) + ' = private constant [' + IntToStr(Len) +
      ' x i8] c"' + EscapeLlvmStr(FStrConstants[I]) + '"');
  end;
end;

procedure THIRLlvmEmitter.EmitStrConcatHelper;
begin
  Emit('');
  Emit('@__heap_cur = internal global ptr null');
  Emit('');
  Emit('define internal ptr @np_alloc(i64 %size) {');
  Emit('entry:');
  Emit('  %cur = load ptr, ptr @__heap_cur');
  Emit('  %is_null = icmp eq ptr %cur, null');
  Emit('  br i1 %is_null, label %init, label %alloc');
  Emit('init:');
  Emit('  %brk0 = call i64 asm sideeffect "movq $$12, %rax\0Axorq %rdi, %rdi\0Asyscall", "={rax},~{rcx},~{r11},~{rdi}"()');
  Emit('  %brk0p = inttoptr i64 %brk0 to ptr');
  Emit('  store ptr %brk0p, ptr @__heap_cur');
  Emit('  br label %alloc');
  Emit('alloc:');
  Emit('  %base = load ptr, ptr @__heap_cur');
  Emit('  %next = getelementptr i8, ptr %base, i64 %size');
  Emit('  %nexti = ptrtoint ptr %next to i64');
  Emit('  call i64 asm sideeffect "movq $$12, %rax\0Asyscall", "={rax},{rdi},~{rcx},~{r11}"(i64 %nexti)');
  Emit('  store ptr %next, ptr @__heap_cur');
  Emit('  ret ptr %base');
  Emit('}');
  Emit('');
  Emit('define internal void @np_memcpy(ptr %dst, ptr %src, i64 %n) {');
  Emit('entry:');
  Emit('  %cmp0 = icmp eq i64 %n, 0');
  Emit('  br i1 %cmp0, label %done, label %loop');
  Emit('loop:');
  Emit('  %i = phi i64 [ 0, %entry ], [ %i_next, %loop ]');
  Emit('  %sp = getelementptr i8, ptr %src, i64 %i');
  Emit('  %b = load i8, ptr %sp');
  Emit('  %dp = getelementptr i8, ptr %dst, i64 %i');
  Emit('  store i8 %b, ptr %dp');
  Emit('  %i_next = add i64 %i, 1');
  Emit('  %cond = icmp eq i64 %i_next, %n');
  Emit('  br i1 %cond, label %done, label %loop');
  Emit('done:');
  Emit('  ret void');
  Emit('}');
  Emit('');
  Emit('define internal {ptr, i64} @np_str_concat(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len) {');
  Emit('entry:');
  Emit('  %total = add i64 %a_len, %b_len');
  Emit('  %buf = call ptr @np_alloc(i64 %total)');
  Emit('  call void @np_memcpy(ptr %buf, ptr %a_ptr, i64 %a_len)');
  Emit('  %dst2 = getelementptr i8, ptr %buf, i64 %a_len');
  Emit('  call void @np_memcpy(ptr %dst2, ptr %b_ptr, i64 %b_len)');
  Emit('  %r1 = insertvalue {ptr, i64} undef, ptr %buf, 0');
  Emit('  %r2 = insertvalue {ptr, i64} %r1, i64 %total, 1');
  Emit('  ret {ptr, i64} %r2');
  Emit('}');
end;

function THIRLlvmEmitter.AsText: string;
var
  I: LongInt;
begin
  Result := '';
  for I := 0 to FLineCount - 1 do
    Result := Result + FLines[I] + LineEnding;
end;

procedure THIRLlvmEmitter.SaveToFile(const APath: string);
var
  F: TextFile;
  I: LongInt;
begin
  AssignFile(F, APath);
  Rewrite(F);
  for I := 0 to FLineCount - 1 do
    WriteLn(F, FLines[I]);
  CloseFile(F);
end;

end.
